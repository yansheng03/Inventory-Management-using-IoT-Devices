/*
 * ESP32-CAM - "THE WORKER" (Corrected, Silent, Serial0 Version)
 * ---------------------------------
 * - USES 'Serial' (GPIO 1(TX) & 3(RX)) FOR ARDUINO COMMUNICATION, matching your wiring.
 * - BAUD RATE IS 19200 to match Arduino SoftwareSerial.
 * - ALL DEBUG 'Serial.print' MESSAGES ARE COMMENTED OUT. This is necessary.
 * - Listens for JSON credentials from Arduino.
 * - Uploads video to Firebase Storage using the correct 'mem_storage_type_sd' enum.
*/

#include <WiFi.h>
#include "esp_camera.h"
#include "Arduino.h"
#include "FS.h"
#include "SD_MMC.h"
#include <ArduinoJson.h>
#include <Firebase_ESP_Client.h>

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

// --- THIS IS THE CHANGE ---
// We use "Serial" (Serial0) to talk to the Arduino, matching your wiring.
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
bool credentialsReceived = false;
bool firebaseReady = false;
bool isRecording = false;
String videoFileName = "";
const char* sdCardMountPoint = "/sdcard";

void setup() {
  // Serial.begin(115200) is now *only* for Arduino communication.
  // Must match the Arduino's ESP32_SERIAL.begin() speed.
  ARDUINO_SERIAL.begin(19200);

  // We can't use Serial.println here anymore.
  // Serial.println("ESP32-CAM Worker Booting...");

  initCamera();
  initSDCard();

  // Serial.println("Waiting for credentials from Arduino via Serial (GPIO 1/3)...");
}

void loop() {
  checkArduinoSerial();

  if (isRecording) {
    captureFrameToFile();
    delay(50);
  }
}

// ===================================
// Serial Communication & State Logic
// ===================================

void checkArduinoSerial() {
  if (ARDUINO_SERIAL.available()) {
    String line = ARDUINO_SERIAL.readStringUntil('\n');
    line.trim();
    if (line.length() == 0) return;

    // Serial.print("Received from Arduino: "); Serial.println(line);

    if (!credentialsReceived && line.startsWith("{") && line.endsWith("}")) {
      JsonDocument doc;
      DeserializationError error = deserializeJson(doc, line);
      if (error) {
        // Serial.print(F("deserializeJson() failed: ")); Serial.println(error.f_str());
        return;
      }
      ssid = doc["ssid"].as<String>();
      pass = doc["pass"].as<String>();
      deviceId = doc["deviceId"].as<String>();

      if (ssid.length() > 0 && deviceId.length() > 0) {
        credentialsReceived = true;
        // Serial.println("Credentials received. Connecting...");
        connectToWiFi();
        initFirebase();
      } else {
         // Serial.println("Received JSON, but SSID or DeviceID is missing.");
      }

    } else if (credentialsReceived) {
      if (line == "START_REC") startRecording();
      else if (line == "STOP_REC") stopAndUpload();
      else if (line == "SNAP") takeAndSendSnapshot();
      // else { Serial.print("Unknown command: "); Serial.println(line); }
    } 
    // else { Serial.println("Waiting for credentials JSON, received other data."); }
  }
}

// ===================================
// WiFi & Firebase Functions
// ===================================

void connectToWiFi() {
  // Serial.print("Connecting to WiFi SSID: "); Serial.println(ssid);
  WiFi.begin(ssid.c_str(), pass.c_str());
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500); // Serial.print(".");
    attempts++;
  }
  if(WiFi.isConnected()){
    // Serial.println("\nWiFi connected!"); Serial.print("IP Address: "); Serial.println(WiFi.localIP());
  } else {
    // Serial.println("\nWiFi connection failed. Restarting...");
    ESP.restart();
  }
}

void initFirebase() {
  // Serial.println("Initializing Firebase...");
  config.api_key = API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void tokenStatusCallback(TokenInfo info) {
  if (info.status == token_status_ready) {
    // Serial.println("Firebase token obtained successfully.");
    firebaseReady = true;
  } else {
    // Serial.printf("Firebase token error: %s\n", info.error.message.c_str());
    firebaseReady = false;
  }
}

// ===================================
// Video Recording Functions
// ===================================

void startRecording() {
  if (isRecording) { /* Serial.println("Already recording."); */ return; }

  if (!SD_MMC.begin(sdCardMountPoint, false) && !SD_MMC.begin(sdCardMountPoint, true)) {
     // Serial.println("SD Card Mount Failed on recording start! Cannot record.");
     return;
  }

  videoFileName = String(sdCardMountPoint) + "/rec_" + String(millis()) + ".mjpeg";
  // Serial.print("Starting recording to SD Card file: "); Serial.println(videoFileName);

  File file = SD_MMC.open(videoFileName, FILE_WRITE);
  if (!file) { /* Serial.println("Failed to open file for writing"); */ return; }
  file.close();
  isRecording = true;
  // Serial.println("Recording started.");
}

void captureFrameToFile() {
  if (!isRecording || videoFileName == "") return;

  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) { /* Serial.println("Camera capture failed"); */ return; }

  File file = SD_MMC.open(videoFileName, FILE_APPEND);
  if (!file) { /* Serial.println("Failed to open file for appending frame"); */ }
  else { file.write(fb->buf, fb->len); file.close(); }

  esp_camera_fb_return(fb);
}

void stopAndUpload() {
  if (!isRecording) { /* Serial.println("Not recording, cannot stop."); */ return; }
  isRecording = false;
  // Serial.println("Recording stopped.");

  if (!firebaseReady) { /* Serial.println("Firebase not ready. Skipping upload."); */ return; }
  if (videoFileName == "") { /* Serial.println("No video file name set. Skipping upload."); */ return; }

  // Serial.print("Initiating upload for: "); Serial.println(videoFileName);
  uploadVideoToFirebase(videoFileName);

  videoFileName = "";
}

// Uploads the specified file from SD card to Firebase Storage
void uploadVideoToFirebase(String& fullPathFilename) {
  if (!SD_MMC.begin(sdCardMountPoint, false) && !SD_MMC.begin(sdCardMountPoint, true)) {
     // Serial.println("SD Card Mount Failed before upload!");
     return;
  }

  if(!SD_MMC.exists(fullPathFilename)){
      // Serial.println("File does not exist, skipping upload: " + fullPathFilename);
      return;
  }

  uint32_t fileSize = 0;
  File file = SD_MMC.open(fullPathFilename, FILE_READ);
  if(file){
      fileSize = file.size();
  } else {
      // Serial.println("Failed to open file for reading size before upload!");
      return;
  }

  if (fileSize == 0) {
      // Serial.println("File is empty, skipping upload and removing.");
      file.close(); 
      SD_MMC.remove(fullPathFilename);
      return;
  }

  // Serial.print("Uploading file: "); Serial.println(fullPathFilename);
  // Serial.print("File size: "); Serial.println(fileSize);

  String filenameOnly = fullPathFilename.substring(fullPathFilename.lastIndexOf('/') + 1);
  String storagePath = "videos/" + deviceId + "/" + filenameOnly;
  String mime = "video/mjpeg";

  // Serial.print("Target Storage Path: "); Serial.println(storagePath);
  // Serial.println("Starting upload using Firebase.Storage.upload...");

  // This is the fix for the compilation errors
  firebase_mem_storage_type storageType = mem_storage_type_sd;
  
  // Call upload with the correct enum type
  // Arguments: Firebase Data Object, Bucket ID, Local File Path, Storage Type Enum, Storage Path, MIME type
  bool uploadSuccess = Firebase.Storage.upload(&fbdo, STORAGE_BUCKET_ID, fullPathFilename.c_str(), storageType, storagePath.c_str(), mime.c_str());

  file.close(); 

  if (uploadSuccess) {
    // Serial.println("------------------------------------");
    // Serial.println("Upload success!");
    String downUrl = fbdo.downloadURL();
    // if (downUrl != "") { Serial.print("Download URL: "); Serial.println(downUrl); }
    // else { Serial.println("Could not retrieve download URL directly."); }
    // Serial.println("------------------------------------");

    if (SD_MMC.remove(fullPathFilename)) { /* Serial.println("File removed from SD card."); */ }
    else { /* Serial.println("Failed to remove file from SD card."); */ }
  } else {
    // Serial.println("Upload failed: " + fbdo.errorReason());
  }
}

// Helper function for URL encoding (kept just in case)
String urlencode(String str)
{
    String encodedString="";
    char c;
    char code0;
    char code1;
    for (unsigned int i =0; i < str.length(); i++){
      c=str.charAt(i);
      if (c == ' '){ encodedString+= '+'; }
      else if (isalnum((unsigned char)c) || c == '-' || c == '_' || c == '.' || c == '~' || c == '/'){ encodedString+=c; }
      else{
        code1=(c & 0xf)+'0';
        if ((c & 0xf) >9){ code1=(c & 0xf) - 10 + 'A'; }
        c=(c>>4)&0xf;
        code0=c+'0';
        if (c > 9){ code0=c - 10 + 'A'; }
        encodedString+='%'; encodedString+=code0; encodedString+=code1;
      }
    }
    return encodedString;
}


// ===================================
// Snapshot Function (for App Request)
// ===================================

void takeAndSendSnapshot() {
  // Serial.println("Snapshot requested by Arduino. Taking picture...");
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    // Serial.println("Camera capture failed for snapshot");
    ARDUINO_SERIAL.println("IMAGE_READY SIZE=0");
    return;
  }

  // Serial.print("Snapshot size: "); Serial.println(fb->len);
  ARDUINO_SERIAL.print("IMAGE_READY SIZE=");
  ARDUINO_SERIAL.println(fb->len);

  unsigned long startTime = millis();
  bool sendCmdReceived = false;
  // Serial.println("Waiting for SEND command from Arduino...");
  while (millis() - startTime < 5000) {
    if (ARDUINO_SERIAL.available()) {
      String cmd = ARDUINO_SERIAL.readStringUntil('\n');
      cmd.trim();
      if (cmd == "SEND") { sendCmdReceived = true; break; }
    }
     delay(10);
  }

  if (sendCmdReceived) {
    // Serial.println("SEND command received. Sending image data to Arduino...");
    size_t bytesSent = ARDUINO_SERIAL.write(fb->buf, fb->len);
    // if (bytesSent == fb->len) Serial.println("Image data sending complete.");
    // else Serial.printf("Image data sending incomplete! Sent %d of %d bytes.\n", bytesSent, fb->len);
  } 
  // else { Serial.println("Timeout waiting for SEND command from Arduino. Aborting snapshot send."); }

  esp_camera_fb_return(fb);
}


// ===================================
// Initialization Functions
// ===================================

void initSDCard() {
  // Serial.println("Initializing SD card (trying 4-bit MMC mode)...");
  if (!SD_MMC.begin(sdCardMountPoint, false)) {
    // Serial.println("SD Card Mount Failed in 4-bit mode! Trying 1-bit mode...");
    if (!SD_MMC.begin(sdCardMountPoint, true)) {
        // Serial.println("SD Card Mount Failed in 1-bit mode too! Check wiring, card (format FAT32?), and power.");
        return;
    } 
    // else { Serial.println("SD Card mounted successfully in 1-bit mode."); }
  } 
  // else { Serial.println("SD Card mounted successfully in 4-bit mode."); }

  uint8_t cardType = SD_MMC.cardType();
  // if (cardType == CARD_NONE) { Serial.println("No SD card attached"); return; }
  // ... (rest of SD card debug messages commented out)
}

void initCamera() {
  // Serial.println("Initializing camera...");
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
    // Serial.printf("Camera init failed with error 0x%x\n", err);
    delay(5000); ESP.restart(); return;
  }

  // sensor_t * s = esp_camera_sensor_get();
  // if (s) { Serial.printf("Camera sensor detected | Pixels: %u\n", s->pixformat); }
  // else { Serial.println("Could not get camera sensor details."); }
  // Serial.println("Camera initialized.");
}