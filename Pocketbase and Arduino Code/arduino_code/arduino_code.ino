/*
 * ARDUINO UNO R4 WIFI - "THE BRAIN" (V11 - With Timeout)
 * ---------------------------------
 * - Uses SoftwareSerial on Pins 10/11.
 * - Blinks for manual reboot.
 * - NEW: Adds a 30-second timeout. If the ESP32 doesn't reply
 * with "IP_WRITE_OK", it will print a debug error.
*/

#include <WiFiS3.h>
#include <ArduinoBLE.h>
#include <ArduinoMDNS.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <WiFiUdp.h>
#include <SoftwareSerial.h> 

// --- Config ---
#define LDR_PIN A0
#define LIGHT_THRESHOLD 700  
const long DEBOUNCE_TIME = 1500;
const unsigned long WIFI_CONNECT_TIMEOUT = 30000; 
#define LED_PIN LED_BUILTIN 
const unsigned long ESP32_REPLY_TIMEOUT = 30000; // 30 seconds

// --- Software Serial (Pins 10, 11) ---
const byte rxPin = 10;
const byte txPin = 11;
SoftwareSerial ESP32_SERIAL(rxPin, txPin); 

// --- BLE UUIDs (with WriteWithoutResponse) ---
BLEService        bleService("19B10000-E8F2-537E-4F6C-D104768A1214");
BLEStringCharacteristic wifiSsidChar("19B10001-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite | BLEWriteWithoutResponse, 32);
BLEStringCharacteristic wifiPassChar("19B10002-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite | BLEWriteWithoutResponse, 64);
BLEStringCharacteristic deviceIdChar("19B10003-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite | BLEWriteWithoutResponse, 32);

// --- Global State ---
Preferences preferences;
WiFiServer server(80);
WiFiUDP udp;
MDNS mdns(udp); 
bool isDoorOpen = false;
unsigned long lastStateChangeTime = 0;

// --- Manual BLE Flags ---
bool ssidWritten = false;
bool passWritten = false;
bool deviceIdWritten = false;
bool credentialsAreSaved = false; 

// --- NEW DEBUG TIMEOUT FLAGS ---
unsigned long lastESP32SendTime = 0;
bool esp32HasReplied = false;

#define SNAPSHOT_BUF_SIZE 1024
byte snapshotBuffer[SNAPSHOT_BUF_SIZE];

// ===================================
//  SETUP & LOOP
// ===================================

void setup() {
  Serial.begin(115200);     // This is for the USB Debug Monitor
  ESP32_SERIAL.begin(19200); // This is for talking to the ESP32
  
  pinMode(LDR_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT); 

  preferences.begin("fridge-creds", false);
  String savedSsid = preferences.getString("ssid", "");

  if (savedSsid.length() == 0) {
    Serial.println("No credentials found. Starting BLE setup...");
    startBLE();
  } else {
    Serial.println("Credentials found. Trying to connect to WiFi...");
    String savedPass = preferences.getString("pass", "");
    
    bool connected = connectToWiFi(savedSsid, savedPass);
    
    if (!connected) {
      Serial.println("Failed to connect with saved credentials.");
      Serial.println("Wiping credentials and restarting in BLE Setup Mode...");
      preferences.clear();
      preferences.end();
      delay(3000);
      NVIC_SystemReset();
    }
    Serial.println("WiFi connection successful. System is running.");
    digitalWrite(LED_PIN, HIGH); // Turn on LED to show we are online
  }
}

// --- LOOP FOR MANUAL REBOOT ---
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    // --- BLE Setup Mode ---
    BLE.poll(); 

    // 1. Check if all credentials have been received
    if (!credentialsAreSaved && ssidWritten && passWritten && deviceIdWritten) {
      Serial.println("\n>>> All 3 credentials received! Saving...");
      
      String ssid = wifiSsidChar.value();
      String pass = wifiPassChar.value();
      String devId = deviceIdChar.value();

      if (ssid.length() > 0 && pass.length() > 0 && devId.length() > 0) {
        preferences.putString("ssid", ssid);
        preferences.putString("pass", pass);
        preferences.putString("deviceId", devId);
        preferences.end(); 
        
        Serial.println("Credentials saved. Disconnecting BLE.");
        Serial.println("Please reboot the device now.");
        BLE.disconnect();
        BLE.end();
        credentialsAreSaved = true; // Set flag so this block doesn't run again
      } else {
        Serial.println(">>> ERROR: Credentials were empty. Resetting setup.");
        ssidWritten = false;
        passWritten = false;
        deviceIdWritten = false;
      }
    }

    // 2. If credentials are saved, blink LED to signal user
    if (credentialsAreSaved) {
      digitalWrite(LED_PIN, HIGH);
      delay(100);
      digitalWrite(LED_PIN, LOW);
      delay(100);
    }
    
  } else {
    // --- WiFi Connected Mode ---
    checkDoorState(); 
    handleClient(); 
  }
  
  // --- Listen for feedback from ESP32 ---
  if (ESP32_SERIAL.available()) {
    String feedback = ESP32_SERIAL.readStringUntil('\n');
    feedback.trim();
    if (feedback.length() > 0) {
      Serial.print(">>> Feedback from ESP32: ");
      Serial.println(feedback);
      if (feedback == "IP_WRITE_OK") {
        esp32HasReplied = true;
      }
    }
  }

  // --- NEW: Check for ESP32 reply timeout ---
  if (lastESP32SendTime != 0 && !esp32HasReplied && (millis() - lastESP32SendTime > ESP32_REPLY_TIMEOUT)) {
    Serial.println(">>> DEBUG: Timeout. No reply received from ESP32.");
    esp32HasReplied = true; // Only print this once per boot
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

  // Set event handler for each characteristic
  wifiSsidChar.setEventHandler(BLEWritten, onCredentialWritten);
  wifiPassChar.setEventHandler(BLEWritten, onCredentialWritten);
  deviceIdChar.setEventHandler(BLEWritten, onCredentialWritten);

  BLE.advertise();
  Serial.println("BLE Advertising as 'InventoryFridge-Setup'...");
}

void onCredentialWritten(BLEDevice central, BLECharacteristic characteristic) {
  if (characteristic.uuid() == wifiSsidChar.uuid()) {
    Serial.println("-> SSID write event.");
    ssidWritten = true;
  }
  if (characteristic.uuid() == wifiPassChar.uuid()) {
    Serial.println("-> Password write event.");
    passWritten = true;
  }
  if (characteristic.uuid() == deviceIdChar.uuid()) {
    Serial.println("-> Device ID write event.");
    deviceIdWritten = true;
  }
}

// ===================================
// WiFi & Server Functions
// ===================================
bool connectToWiFi(String ssid, String pass) {
  Serial.print("Attempting to connect to SSID: ");
  Serial.println(ssid);
  WiFi.begin(ssid.c_str(), pass.c_str());
  unsigned long startTime = millis();
  while (WiFi.status() != WL_CONNECTED || WiFi.localIP() == IPAddress(0,0,0,0)) {
    if (millis() - startTime > WIFI_CONNECT_TIMEOUT) {
      Serial.println("\nConnection FAILED (Timeout).");
      WiFi.disconnect();
      return false;
    }
    Serial.print(".");
    delay(1000); 
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
  return true;
}
void sendCredentialsToESP() {
  Serial.println("Sending credentials (and IP) to ESP32 via SoftwareSerial...");
  String deviceId = preferences.getString("deviceId", "");
  String ssid = preferences.getString("ssid", "");
  String pass = preferences.getString("pass", "");
  String arduinoIP = WiFi.localIP().toString();
  JsonDocument doc; 
  doc["ssid"] = ssid;
  doc["pass"] = pass;
  doc["deviceId"] = deviceId;
  doc["arduino_ip"] = arduinoIP; 
  serializeJson(doc, ESP32_SERIAL);
  ESP32_SERIAL.println(); 
  Serial.println("Credentials and IP sent. Waiting for ESP32 reply...");
  
  // --- NEW: Start the timeout timer ---
  lastESP32SendTime = millis();
  esp32HasReplied = false;
}
void handleClient() {
  WiFiClient client = server.available(); 
  if (!client) { return; }
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
          } else if (currentRequest.startsWith("POST /forget-wifi")) { 
            handleForgetWifi(client);
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
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: image/jpeg");
  client.println("Connection: close");
  client.print("Content-Length: ");
  client.println(snapshotSize);
  client.println(); 
  ESP32_SERIAL.println("SEND");
  long bytesRead = 0;
  startTime = millis(); 
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
void handleForgetWifi(WiFiClient client) {
  Serial.println("Received /forget-wifi request. Wiping credentials and restarting.");
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: application/json");
  client.println("Connection: close");
  client.println();
  client.print("{\"message\": \"Credentials wiped. Device is restarting.\"}");
  delay(100); 
  client.stop();
  preferences.clear();
  preferences.end();
  delay(2000); 
  NVIC_SystemReset();
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