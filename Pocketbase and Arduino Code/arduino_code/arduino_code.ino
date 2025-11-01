/*
 * ARDUINO UNO R4 WIFI - "THE BRAIN" (SoftwareSerial Version)
 * ---------------------------------
 * - Uses SoftwareSerial on pins 10(RX) and 11(TX) at 19200 BAUD.
 * - Leaves D0/D1 free for USB monitor and uploads.
 * - Handles BLE setup for WiFi/Device ID.
 * - Connects to WiFi, starts HTTP server, and advertises via mDNS.
 * - Monitors LDR (A0) and sends START/STOP_REC to ESP32.
 * - Handles /status and /snapshot HTTP requests from the app.
*/

#include <WiFiS3.h>
#include <ArduinoBLE.h>
#include <ArduinoMDNS.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <WiFiUdp.h>
#include <SoftwareSerial.h> // <-- *** NEW: INCLUDE SOFTWARE SERIAL ***

// --- *** NEW: DEFINE SOFTWARE SERIAL PINS *** ---
const byte rxPin = 10;
const byte txPin = 11;
// RX pin 10 (Connects to ESP32 TX pin U0T)
// TX pin 11 (Connects to ESP32 RX pin U0R)
SoftwareSerial ESP32_SERIAL(rxPin, txPin); 

// --- Config ---
#define LDR_PIN A0
#define LIGHT_THRESHOLD 700  // YOU MUST TUNE THIS VALUE. Test analogRead(LDR_PIN).
const long DEBOUNCE_TIME = 1500; // 1.5 seconds

// --- BLE UUIDs ---
BLEService        bleService("19B10000-E8F2-537E-4F6C-D104768A1214");
BLEStringCharacteristic wifiSsidChar("19B10001-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite, 32);
BLEStringCharacteristic wifiPassChar("19B10002-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite, 64);
BLEStringCharacteristic deviceIdChar("19B10003-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite, 32);

// --- Global State ---
Preferences preferences;
WiFiServer server(80);
WiFiUDP udp; // Needed for MDNS constructor
MDNS mdns(udp); // Pass UDP object to constructor
bool isDoorOpen = false;
unsigned long lastStateChangeTime = 0;
bool credentialsReceived = false;

// Buffer for snapshot
#define SNAPSHOT_BUF_SIZE 1024
byte snapshotBuffer[SNAPSHOT_BUF_SIZE];

void setup() {
  Serial.begin(115200); // USB Serial Monitor (Fast)
  
  // --- *** THIS IS THE CHANGE *** ---
  // Use 19200 baud for stable Software Serial communication
  ESP32_SERIAL.begin(19200); // For ESP32-CAM
  
  pinMode(LDR_PIN, INPUT);

  preferences.begin("fridge-creds", false);
  String savedSsid = preferences.getString("ssid", "");

  if (savedSsid.length() == 0) {
    Serial.println("No credentials found. Starting BLE setup...");
    startBLE();
  } else {
    Serial.println("Credentials found. Connecting to WiFi...");
    String savedPass = preferences.getString("pass", "");
    connectToWiFi(savedSsid, savedPass);
  }
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    // --- BLE Setup Mode ---
    BLE.poll(); 

    if (credentialsReceived) {
      Serial.println("Received new credentials via BLE.");
      preferences.putString("ssid", wifiSsidChar.value());
      preferences.putString("pass", wifiPassChar.value());
      preferences.putString("deviceId", deviceIdChar.value());
      preferences.end(); 
      
      Serial.println("Credentials saved. Restarting in 3 seconds...");
      BLE.disconnect();
      BLE.end();
      delay(3000);
      NVIC_SystemReset(); 
    }
  } else {
    // --- WiFi Connected Mode ---
    checkDoorState(); 
    // mDNS polling/update removed, assuming background operation for v1.0.0
    handleClient(); 
  }
  
  // SoftwareSerial needs to be listened to constantly
  // (We do this inside handleSnapshot, but this is good practice if ESP32 ever sends unsolicited data)
  while (ESP32_SERIAL.available()) {
    ESP32_SERIAL.read(); // Clear buffer
  }
}

// ===================================
// BLE Setup Functions
// ===================================

void startBLE() {
  if (!BLE.begin()) {
    Serial.println("Failed to start BLE!");
    while (1); 
  }
  
  BLE.setLocalName("InventoryFridge-Setup");
  BLE.setAdvertisedService(bleService);
  bleService.addCharacteristic(wifiSsidChar);
  bleService.addCharacteristic(wifiPassChar);
  bleService.addCharacteristic(deviceIdChar);
  BLE.addService(bleService);

  wifiSsidChar.setEventHandler(BLEWritten, onCredentialWritten);
  wifiPassChar.setEventHandler(BLEWritten, onCredentialWritten);
  deviceIdChar.setEventHandler(BLEWritten, onCredentialWritten);

  BLE.advertise();
  Serial.println("BLE Advertising as 'InventoryFridge-Setup'...");
}

void onCredentialWritten(BLEDevice central, BLECharacteristic characteristic) {
  if (wifiSsidChar.written() && wifiPassChar.written() && deviceIdChar.written()) {
    Serial.println("All credentials received via BLE.");
    credentialsReceived = true; 
  }
}

// ===================================
// WiFi & Server Functions
// ===================================

void connectToWiFi(String ssid, String pass) {
  int status = WL_IDLE_STATUS;
  Serial.print("Attempting to connect to SSID: ");
  Serial.println(ssid);
  
  while (status != WL_CONNECTED) {
    status = WiFi.begin(ssid.c_str(), pass.c_str());
    Serial.print(".");
    delay(5000); 
  }
  
  Serial.println("\nWiFi connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  if (!mdns.begin("inventory-fridge")) { 
    Serial.println("Error setting up mDNS responder!");
  } else {
    Serial.println("mDNS responder started at 'inventory-fridge.local'");
  }
  
  server.begin();
  mdns.addServiceRecord("_http", 80, MDNSServiceTCP);
  Serial.println("HTTP service registered via mDNS.");

  sendCredentialsToESP();
}

void sendCredentialsToESP() {
  Serial.println("Sending credentials to ESP32...");
  
  String deviceId = preferences.getString("deviceId", "");
  String ssid = preferences.getString("ssid", "");
  String pass = preferences.getString("pass", "");

  JsonDocument doc; 
  doc["ssid"] = ssid;
  doc["pass"] = pass;
  doc["deviceId"] = deviceId;

  serializeJson(doc, ESP32_SERIAL);
  ESP32_SERIAL.println(); 
  Serial.println("Credentials sent.");
}

void handleClient() {
  WiFiClient client = server.available(); 
  if (!client) {
    return; 
  }
  
  Serial.println("New client connected.");
  String currentLine = "";    
  String currentRequest = ""; 

  while (client.connected()) {
    if (client.available()) { 
      char c = client.read();  
      Serial.write(c);       
      
      if (c == '\n') { 
        if (currentLine.length() == 0) {
          if (currentRequest.startsWith("GET /status")) {
            handleStatus(client);
          } else if (currentRequest.startsWith("POST /snapshot")) {
            handleSnapshot(client);
          } else {
            handleNotFound(client); 
          }
          break; 
        } else {
          if (currentLine.startsWith("GET") || currentLine.startsWith("POST")) {
            currentRequest = currentLine;
          }
          currentLine = "";
        }
      } else if (c != '\r') {
        currentLine += c;
      }
    }
  }
  client.stop();
  Serial.println("Client disconnected.");
}

void handleStatus(WiFiClient client) {
  String status = isDoorOpen ? "open" : "closed";
  String json = "{\"status\": \"" + status + "\"}";
  
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: application/json");
  client.println("Connection: close"); 
  client.print("Content-Length: ");
  client.println(json.length());
  client.println(); 
  client.print(json); 
}

void handleSnapshot(WiFiClient client) {
  Serial.println("Snapshot requested. Asking ESP32...");
  ESP32_SERIAL.println("SNAP"); 

  unsigned long startTime = millis();
  String line = "";
  long snapshotSize = 0;

  // 1. Wait for "IMAGE_READY SIZE=..." response from ESP32
  // Increased timeout for slower serial
  while (millis() - startTime < 15000) { 
    if (ESP32_SERIAL.available()) {
      char c = ESP32_SERIAL.read();
      if (c == '\n') { 
        if (line.startsWith("IMAGE_READY SIZE=")) {
          snapshotSize = line.substring(17).toInt();
          break; 
        }
        line = ""; 
      } else if (c != '\r') {
        line += c; 
      }
    }
  }

  // Check if size was received
  if (snapshotSize == 0) {
    Serial.println("Timeout or error waiting for snapshot size from ESP32.");
    client.println("HTTP/1.1 500 Internal Server Error");
    client.println("Content-Length: 0");
    client.println("Connection: close");
    client.println();
    return;
  }

  Serial.print("ESP32 is ready to send snapshot. Size: ");
  Serial.println(snapshotSize);

  // 2. Send HTTP headers back to the Flutter app client
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: image/jpeg");
  client.println("Connection: close");
  client.print("Content-Length: ");
  client.println(snapshotSize);
  client.println(); // End of headers

  // 3. Tell ESP32 to start sending the image data
  ESP32_SERIAL.println("SEND");

  // 4. Relay image data
  long bytesRead = 0;
  startTime = millis(); 
  // Increase timeout for 19200 baud
  while (bytesRead < snapshotSize && millis() - startTime < 30000) { 
    if (ESP32_SERIAL.available()) {
      int bytesToRead = min((int)ESP32_SERIAL.available(), SNAPSHOT_BUF_SIZE);
      bytesToRead = min(bytesToRead, (int)(snapshotSize - bytesRead));
      
      int readCount = ESP32_SERIAL.readBytes(snapshotBuffer, bytesToRead);
      
      if (readCount > 0) {
        client.write(snapshotBuffer, readCount);
        bytesRead += readCount;
        startTime = millis(); 
      }
    }
  }

  if (bytesRead != snapshotSize) {
    Serial.println("Snapshot transfer failed or timed out!");
  } else {
    Serial.println("Snapshot transfer complete.");
  }
}

void handleNotFound(WiFiClient client) {
  client.println("HTTP/1.1 404 Not Found");
  client.println("Content-Type: text/plain");
  client.println("Connection: close");
  client.println();
  client.print("Not Found");
}

// ===================================
// LDR Logic
// ===================================

void checkDoorState() {
  int ldrValue = analogRead(LDR_PIN);
  bool currentlyOpen = (ldrValue > LIGHT_THRESHOLD); 

  if (currentlyOpen != isDoorOpen && millis() - lastStateChangeTime > DEBOUNCE_TIME) {
    isDoorOpen = currentlyOpen; 
    lastStateChangeTime = millis(); 
    
    if (isDoorOpen) {
      Serial.println("Door opened (LDR Light High). Sending START_REC to ESP32.");
      ESP32_SERIAL.println("START_REC"); 
    } else {
      Serial.println("Door closed (LDR Light Low). Sending STOP_REC to ESP32.");
      ESP32_SERIAL.println("STOP_REC");
    }
  }
}