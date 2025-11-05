/*
 * ESP32-CAM - "THE WORKER" (V24 - NO SD CARD FIX)
 * ---------------------------------
 * - This version REMOVES all SD card functionality.
 * - FIX 1: Uses Hardware Serial 0 (U0R/U0T) for reliable communication.
 * - FIX 2: Uses a Manual JSON payload to bypass the library bug.
 * - FIX 3: Sends "IP_WRITE_OK" feedback to Arduino on success.
*/

#include <WiFi.h>
#include "esp_camera.h"
#include "Arduino.h"
// #include "FS.h"           // <-- REMOVED
// #include "SD_MMC.h"       // <-- REMOVED
#include <ArduinoJson.h>
#include <Firebase_ESP_Client.h> 
// NO SoftwareSerial.h

// --- !!! IMPORTANT: CONFIGURE FIREBASE !!! ---
#define API_KEY "AIzaSyAz2zHTxPNEGjD6LPVjo8cGA-tI18JDOxg"
#define FIREBASE_PROJECT_ID "iot-inventory-management-7c555"
#define USER_EMAIL "esp32@gmail.com"
#define USER_PASSWORD "1234567890"
#define STORAGE_BUCKET_ID FIREBASE_PROJECT_ID ".appspot.com"
// -------------------------------------------

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// --- *** FIX 1: Use Hardware Serial 0 (U0R, U0T) *** ---
#define ARDUINO_SERIAL Serial

// --- Camera Pin Defs (AI-THINKER Model - Standard) ---
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// --- Global State ---
String deviceId = "";
String ssid = "";
String pass = "";
String arduinoIP = ""; 
bool credentialsReceived = false;
bool firebaseReady = false;
// bool isRecording = false; // <-- REMOVED
// String videoFileName = ""; // <-- REMOVED
// const char* sdCardMountPoint = "/sdcard"; // <-- REMOVED

void setup() {
  // Initialize Hardware Serial 0 at 19200 baud
  ARDUINO_SERIAL.begin(19200); 
  
  initCamera();
  // initSDCard(); // <-- REMOVED
}

void loop() {
  checkArduinoSerial();

  // if (isRecording) { // <-- REMOVED
  //   captureFrameToFile(); // <-- REMOVED
  //   delay(50); // <-- REMOVED
  // } // <-- REMOVED
}

// ===================================
// Serial Communication & State Logic
// ===================================

// --- *** FIX 2 & 3: MANUAL JSON + FEEDBACK *** ---
void updateIpInFirestore() {
  if (!firebaseReady || deviceId == "" || arduinoIP == "") {
    return;
  }
  
  // This is the path to the document we want to create
  String documentPath = "device_locations/" + deviceId;

  // Manual JSON payload (from our successful V7 test)
  String jsonPayload = "{";
  jsonPayload += "\"fields\": {";
  jsonPayload += "\"ip\": {\"stringValue\": \"" + arduinoIP + "\"}";
  jsonPayload += "}";
  jsonPayload += "}";

  // We use createDocument, which we know works
  if (Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), jsonPayload.c_str())) {
    ARDUINO_SERIAL.println("IP_WRITE_OK"); // Send success back to Arduino
  } else {
    ARDUINO_SERIAL.println("IP_WRITE_FAIL"); // Send fail back to Arduino
  }
}


void checkArduinoSerial() {
  if (ARDUINO_SERIAL.available()) {
    String line = ARDUINO_SERIAL.readStringUntil('\n');
    line.trim();
    if (line.length() == 0) return;

    if (!credentialsReceived && line.startsWith("{") && line.endsWith("}")) {
      JsonDocument doc;
      DeserializationError error = deserializeJson(doc, line);
      if (error) {
        return;
      }
      ssid = doc["ssid"].as<String>();
      pass = doc["pass"].as<String>();
      deviceId = doc["deviceId"].as<String>();
      arduinoIP = doc["arduino_ip"].as<String>();

      if (ssid.length() > 0 && deviceId.length() > 0) {
        credentialsReceived = true;
        connectToWiFi();
        initFirebase(); 
      }
    } else if (credentialsReceived) {
      // --- SD CARD FUNCTIONS REMOVED ---
      // if (line == "START_REC") startRecording(); 
      // else if (line == "STOP_REC") stopAndUpload();
      if (line == "SNAP") takeAndSendSnapshot();
    } 
  }
}

// ===================================
// WiFi & Firebase Functions
// ===================================

void connectToWiFi() {
  WiFi.begin(ssid.c_str(), pass.c_str());
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    attempts++;
  }
  if(!WiFi.isConnected()){
    ESP.restart();
  }
}

void initFirebase() {
  config.api_key = API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void tokenStatusCallback(TokenInfo info) {
  if (info.status == token_status_ready) {
    firebaseReady = true;
    updateIpInFirestore(); // Once ready, update the IP
  } else {
    firebaseReady = false;
  }
}

// ===================================
// Video Recording Functions (DISABLED)
// ===================================

void startRecording() {
  // Do nothing
}

void captureFrameToFile() {
  // Do nothing
}

void stopAndUpload() {
  // Do nothing
}

void uploadVideoToFirebase(String& fullPathFilename) {
  // Do nothing
}

// ===================================
// Snapshot Function (for App Request)
// ===================================

void takeAndSendSnapshot() {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    ARDUINO_SERIAL.println("IMAGE_READY SIZE=0");
    return;
  }

  ARDUINO_SERIAL.print("IMAGE_READY SIZE=");
  ARDUINO_SERIAL.println(fb->len);

  unsigned long startTime = millis();
  bool sendCmdReceived = false;
  while (millis() - startTime < 5000) {
    if (ARDUINO_SERIAL.available()) {
      String cmd = ARDUINO_SERIAL.readStringUntil('\n');
      cmd.trim();
      if (cmd == "SEND") { sendCmdReceived = true; break; }
    }
     delay(10);
  }

  if (sendCmdReceived) {
    ARDUINO_SERIAL.write(fb->buf, fb->len);
  } 

  esp_camera_fb_return(fb);
}

// ===================================
// Initialization Functions
// ===================================

void initSDCard() {
  // Do nothing
}

void initCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM; config.pin_d1 = Y3_GPIO_NUM; config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM; config.pin_d4 = Y6_GPIO_NUM; config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM; config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM; config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM; config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM; config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM; config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000; config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_VGA; config.jpeg_quality = 12;
  config.fb_count = 1; 
  #if CONFIG_CAMERA_PSRAM_SUPPORT 
  config.fb_location = CAMERA_FB_IN_PSRAM;
  #else
  config.fb_location = CAMERA_FB_IN_DRAM;
  #endif
  config.grab_mode = CAMERA_GRAB_LATEST;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    delay(5000); 
    ESP.restart();
  }
}