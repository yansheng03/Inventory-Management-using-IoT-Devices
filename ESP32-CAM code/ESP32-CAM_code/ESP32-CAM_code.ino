
#include <Arduino.h>
#include <WiFi.h>
#include <ESPmDNS.h>
#include <WebServer.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Preferences.h>
#include <nvs_flash.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include "esp_camera.h"
#include "SD_MMC.h"
#include <Firebase_ESP_Client.h>
#include <FS.h>
#include <time.h>

// ========================== CONFIG ==========================
//Make an account for the ESP32-CAM
#define FIREBASE_USER_EMAIL "" //Hardcoded email for ESP32-CAM use
#define FIREBASE_USER_PASSWORD "" //Hardcoded password for ESP32-CAM use
//Hardcoded as well
#define API_KEY "" //Enter your database API KEY
#define STORAGE_BUCKET "" //Enter your database storage bucket

// --- HARDWARE SETTINGS ---
#define PIR_PIN 13
#define STATUS_LED 33
#define FLASH_LED_PIN 4

#define PIR_ACTIVE_STATE LOW 

#define TIME_OFFSET 28800  // UTC+8 (Singapore/Malaysia)

// --- STORAGE SETTINGS ---
const unsigned long FILE_RETENTION_SEC = 172800;  // 2 Days
const unsigned long LOG_RETENTION_SEC = 172800;   // 2 Days
const unsigned long CLEANUP_INTERVAL = 86400000;  // 24 Hours

const unsigned long RECORD_EXTENSION_TIME = 15000;
const unsigned long MAX_RECORD_TIME = 600000;
const unsigned long WARMUP_TIME = 15000;
const unsigned long PIR_POLL_INTERVAL = 150;

// Camera Pins (AI-Thinker Model)
#define PWDN_GPIO_NUM 32
#define RESET_GPIO_NUM -1
#define XCLK_GPIO_NUM 0
#define SIOD_GPIO_NUM 26
#define SIOC_GPIO_NUM 27
#define Y9_GPIO_NUM 35
#define Y8_GPIO_NUM 34
#define Y7_GPIO_NUM 39
#define Y6_GPIO_NUM 36
#define Y5_GPIO_NUM 21
#define Y4_GPIO_NUM 19
#define Y3_GPIO_NUM 18
#define Y2_GPIO_NUM 5
#define VSYNC_GPIO_NUM 25
#define HREF_GPIO_NUM 23
#define PCLK_GPIO_NUM 22

// BLE UUIDs
#define SERVICE_UUID "19B10000-E8F2-537E-4F6C-D104768A1214"
#define SSID_CHAR_UUID "19B10001-E8F2-537E-4F6C-D104768A1214"
#define PASS_CHAR_UUID "19B10002-E8F2-537E-4F6C-D104768A1214"
#define DEVICE_ID_CHAR_UUID "19B10003-E8F2-537E-4F6C-D104768A1214"
#define STATUS_CHAR_UUID "19B10004-E8F2-537E-4F6C-D104768A1214"
#define OWNER_ID_CHAR_UUID "19B10005-E8F2-537E-4F6C-D104768A1214"

Preferences preferences;
String wifi_ssid = "";
String wifi_pass = "";
String device_id = "";
String owner_id = "";

WebServer server(80);
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
bool firebaseReady = false;
BLECharacteristic *pStatusChar;

enum SystemState { STATE_WARMUP,
                   STATE_IDLE,
                   STATE_RECORDING,
                   STATE_UPLOADING,
                   STATE_COOLDOWN };
SystemState currentState = STATE_WARMUP;

bool isArmed = false;
unsigned long motionStopTime = 0;
unsigned long recordingStartTime = 0;
unsigned long bootTime = 0;
unsigned long lastWifiCheck = 0; 

bool sdOk = false;
bool ntpOk = false;
bool cameraReady = false;
const char *DEBUG_LOG = "/logs/debug.txt";
String currentFilePath = "";
File aviFile;
unsigned long lastPirPoll = 0;

unsigned long currentFrameCount = 0;
unsigned long lastStorageCleanup = 0;

// Loop Flags
bool isRestarting = false;
bool shouldVerifyAndSave = false;

// --- Forward Declarations ---
void uploadRecording(); 
bool cameraInit();
void cameraDeinit();
void startRecording();
void stopRecording();
void captureFrame();

String getLogTime() {
  struct tm tm;
  if (getLocalTime(&tm)) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%04d-%02d-%02d %02d:%02d:%02d",
             tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
             tm.tm_hour, tm.tm_min, tm.tm_sec);
    return String(buf);
  }
  return String(millis());
}

void writeDebug(const String &msg) {
  Serial.println(msg);
  if (sdOk && currentState != STATE_UPLOADING && currentState != STATE_RECORDING) {
    File f = SD_MMC.open(DEBUG_LOG, FILE_APPEND);
    if (f) {
      f.print(getLogTime());
      f.print(": ");
      f.println(msg);
      f.close();
    }
  }
}

String generateFilename() {
  struct tm tm;
  if (getLocalTime(&tm)) {
    char buf[64];
    snprintf(buf, sizeof(buf), "/recordings/VID_%04d%02d%02d_%02d%02d%02d.avi",
             tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
             tm.tm_hour, tm.tm_min, tm.tm_sec);
    return String(buf);
  }
  return "/recordings/VID_ms" + String(millis()) + ".avi";
}

void pruneLogs() {
  if (!sdOk || !ntpOk) return;
  if (!SD_MMC.exists(DEBUG_LOG)) return;

  writeDebug("[Storage] Pruning old logs...");
  SD_MMC.rename(DEBUG_LOG, "/logs/temp.txt");

  File readFile = SD_MMC.open("/logs/temp.txt", FILE_READ);
  File writeFile = SD_MMC.open(DEBUG_LOG, FILE_WRITE);

  if (!readFile || !writeFile) {
    if (readFile) readFile.close();
    if (writeFile) writeFile.close();
    return;
  }

  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return;
  time_t now = mktime(&timeinfo);

  while (readFile.available()) {
    String line = readFile.readStringUntil('\n');
    if (line.length() > 19) {
      String datePart = line.substring(0, 19);
      if (datePart.startsWith("20")) {
        int y = datePart.substring(0, 4).toInt();
        int m = datePart.substring(5, 7).toInt();
        int d = datePart.substring(8, 10).toInt();
        int h = datePart.substring(11, 13).toInt();
        int min = datePart.substring(14, 16).toInt();
        int s = datePart.substring(17, 19).toInt();
        struct tm logTm = { 0 };
        logTm.tm_year = y - 1900;
        logTm.tm_mon = m - 1;
        logTm.tm_mday = d;
        logTm.tm_hour = h;
        logTm.tm_min = min;
        logTm.tm_sec = s;

        if (difftime(now, mktime(&logTm)) <= LOG_RETENTION_SEC) {
          writeFile.println(line);
        }
      }
    }
  }
  readFile.close();
  writeFile.close();
  SD_MMC.remove("/logs/temp.txt");
}

void cleanupOldFiles() {
  if (!sdOk || !ntpOk) return;
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return;
  time_t now = mktime(&timeinfo);

  writeDebug("[Storage] Checking old videos...");
  File root = SD_MMC.open("/recordings");
  if (!root || !root.isDirectory()) return;

  File file = root.openNextFile();
  while (file) {
    if (!file.isDirectory()) {
      String path = String(file.path());
      int idx = path.indexOf("VID_");
      if (idx != -1 && path.length() >= idx + 19) {
        String yStr = path.substring(idx + 4, idx + 8);
        String mStr = path.substring(idx + 8, idx + 10);
        String dStr = path.substring(idx + 10, idx + 12);
        String hStr = path.substring(idx + 13, idx + 15);
        String minStr = path.substring(idx + 15, idx + 17);
        String sStr = path.substring(idx + 17, idx + 19);
        struct tm ft = { 0 };
        ft.tm_year = yStr.toInt() - 1900;
        ft.tm_mon = mStr.toInt() - 1;
        ft.tm_mday = dStr.toInt();
        ft.tm_hour = hStr.toInt();
        ft.tm_min = minStr.toInt();
        ft.tm_sec = sStr.toInt();

        if (difftime(now, mktime(&ft)) > FILE_RETENTION_SEC) {
          writeDebug("[Storage] Deleting: " + path);
          String p = path;
          file.close();
          SD_MMC.remove(p);
          file = root.openNextFile();
          continue;
        }
      }
    }
    file = root.openNextFile();
  }
  root.close();
  pruneLogs();
}

bool initSD() {
  if (SD_MMC.cardType() != CARD_NONE) return true;
  if (!SD_MMC.begin("/sdcard", true, false, 4000)) return false;
  return (SD_MMC.cardType() != CARD_NONE);
}

// --- IMPROVED: Double Buffering Enabled ---
bool cameraInit() {
  if (cameraReady) return true;

  writeDebug("Initializing Camera...");
  digitalWrite(PWDN_GPIO_NUM, HIGH);
  delay(100);
  digitalWrite(PWDN_GPIO_NUM, LOW);
  delay(100);

  camera_config_t config_cam;
  config_cam.ledc_channel = LEDC_CHANNEL_0;
  config_cam.ledc_timer = LEDC_TIMER_0;
  config_cam.pin_d0 = Y2_GPIO_NUM;
  config_cam.pin_d1 = Y3_GPIO_NUM;
  config_cam.pin_d2 = Y4_GPIO_NUM;
  config_cam.pin_d3 = Y5_GPIO_NUM;
  config_cam.pin_d4 = Y6_GPIO_NUM;
  config_cam.pin_d5 = Y7_GPIO_NUM;
  config_cam.pin_d6 = Y8_GPIO_NUM;
  config_cam.pin_d7 = Y9_GPIO_NUM;
  config_cam.pin_xclk = XCLK_GPIO_NUM;
  config_cam.pin_pclk = PCLK_GPIO_NUM;
  config_cam.pin_vsync = VSYNC_GPIO_NUM;
  config_cam.pin_href = HREF_GPIO_NUM;
  config_cam.pin_sscb_sda = SIOD_GPIO_NUM;
  config_cam.pin_sscb_scl = SIOC_GPIO_NUM;
  config_cam.pin_pwdn = PWDN_GPIO_NUM;
  config_cam.pin_reset = RESET_GPIO_NUM;
  config_cam.xclk_freq_hz = 20000000;
  config_cam.pixel_format = PIXFORMAT_JPEG;
  config_cam.frame_size = FRAMESIZE_VGA;
  config_cam.jpeg_quality = 10;

  // --- DOUBLE BUFFERING CHECK ---
  if (psramFound()) {
    config_cam.fb_count = 2; // Smoother video
    config_cam.grab_mode = CAMERA_GRAB_LATEST;
  } else {
    config_cam.fb_count = 1;
    config_cam.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
  }

  if (esp_camera_init(&config_cam) != ESP_OK) {
    writeDebug("Camera Init Failed!");
    digitalWrite(PWDN_GPIO_NUM, HIGH);
    return false;
  }

  sensor_t *s = esp_camera_sensor_get();
  if (s != NULL) {
    s->set_vflip(s, 1);    // Change to 1 if image is Upside Down
    s->set_hmirror(s, 0);  // Change to 1 if image is Mirrored
  }

  cameraReady = true;
  writeDebug("Camera Init Success.");
  return true;
}

void cameraDeinit() {
  if (!cameraReady) return;
  esp_camera_deinit();
  digitalWrite(PWDN_GPIO_NUM, HIGH);
  cameraReady = false;
  writeDebug("Camera De-initialized.");
}

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) {
    writeDebug("BLE Connected");
  };
  void onDisconnect(BLEServer *pServer) {
    writeDebug("BLE Disconnected");
    if (!isRestarting && !shouldVerifyAndSave) {
      wifi_ssid = "";
      wifi_pass = "";
      device_id = "";
      owner_id = "";
      writeDebug("Setup Aborted: Creds Cleared");
    }
    BLEDevice::startAdvertising();
  };
};

class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pChar) {
    String val = pChar->getValue().c_str();
    String uuid = pChar->getUUID().toString();
    if (uuid.equalsIgnoreCase(SSID_CHAR_UUID)) wifi_ssid = val;
    else if (uuid.equalsIgnoreCase(PASS_CHAR_UUID)) wifi_pass = val;
    else if (uuid.equalsIgnoreCase(OWNER_ID_CHAR_UUID)) owner_id = val;
    else if (uuid.equalsIgnoreCase(DEVICE_ID_CHAR_UUID)) {
      device_id = val;
      if (wifi_ssid != "" && wifi_pass != "") shouldVerifyAndSave = true;
    }
  }
};

void startBLEMode() {
  if (cameraReady) cameraDeinit();

  WiFi.mode(WIFI_OFF);
  BLEDevice::init("InventoryFridge-Setup");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);
  uint32_t props = BLECharacteristic::PROPERTY_WRITE;

  pService->createCharacteristic(SSID_CHAR_UUID, props)->setCallbacks(new ConfigCallbacks());
  pService->createCharacteristic(PASS_CHAR_UUID, props)->setCallbacks(new ConfigCallbacks());
  pService->createCharacteristic(DEVICE_ID_CHAR_UUID, props)->setCallbacks(new ConfigCallbacks());
  pService->createCharacteristic(OWNER_ID_CHAR_UUID, props)->setCallbacks(new ConfigCallbacks());
  pStatusChar = pService->createCharacteristic(STATUS_CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  pStatusChar->addDescriptor(new BLE2902());

  pService->start();
  BLEDevice::getAdvertising()->addServiceUUID(SERVICE_UUID);
  BLEDevice::getAdvertising()->start();
  writeDebug("BLE Started (Cam OFF)");
}

void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  Serial.begin(115200);
  pinMode(PIR_PIN, INPUT);
  pinMode(STATUS_LED, OUTPUT);
  pinMode(PWDN_GPIO_NUM, OUTPUT);
  pinMode(FLASH_LED_PIN, OUTPUT);
  digitalWrite(FLASH_LED_PIN, LOW);
  digitalWrite(STATUS_LED, HIGH);

  preferences.begin("cam_config", true);
  wifi_ssid = preferences.getString("ssid", "");
  wifi_pass = preferences.getString("pass", "");
  device_id = preferences.getString("devid", "");
  owner_id = preferences.getString("owner", "");
  preferences.end();

  bootTime = millis();

  if (initSD()) {
    sdOk = true;
    SD_MMC.mkdir("/logs");
    SD_MMC.mkdir("/recordings");
    writeDebug("SD Mounted.");
  } else {
    Serial.println("SD Mount Failed");
  }

  if (wifi_ssid == "" || device_id == "") {
    startBLEMode();
  } else {
    WiFi.mode(WIFI_STA);
    WiFi.begin(wifi_ssid.c_str(), wifi_pass.c_str());
    writeDebug("Connecting to: " + wifi_ssid);

    int retries = 0;
    while (WiFi.status() != WL_CONNECTED && retries < 25) {
      delay(500);
      retries++;
      Serial.print(".");
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
      writeDebug("WiFi Connected! IP: " + WiFi.localIP().toString());

      cameraInit();  // Init Camera only AFTER WiFi

      if (MDNS.begin("inventory-fridge")) MDNS.addService("http", "tcp", 80);

      server.on("/set-time", HTTP_POST, []() {
        if (server.hasArg("timestamp")) {
          String tsStr = server.arg("timestamp");
          long long ts = atoll(tsStr.c_str());
          if (ts > 1000000000) {
            struct timeval tv;
            tv.tv_sec = ts / 1000;
            tv.tv_usec = 0;
            settimeofday(&tv, NULL);
            writeDebug("Time Synced");
            server.send(200, "text/plain", "Time Set");
          } else server.send(400, "text/plain", "Invalid");
        }
      });

      server.on("/status", HTTP_GET, []() {
        server.send(200, "application/json", "{\"status\":\"online\"}");
      });

      server.on("/forget-wifi", HTTP_POST, []() {
        writeDebug("CMD: Forget WiFi");
        server.send(200, "text/plain", "Resetting");
        preferences.begin("cam_config", false);
        preferences.clear();
        preferences.end();
        nvs_flash_erase();
        nvs_flash_init();
        delay(500);
        ESP.restart();
      });

      server.on("/clear-logs", HTTP_POST, []() {
        if (sdOk && SD_MMC.exists(DEBUG_LOG)) {
          SD_MMC.remove(DEBUG_LOG);
          writeDebug("Logs Cleared");
          server.send(200, "text/plain", "Logs Cleared");
        } else server.send(400, "text/plain", "No logs");
      });

      server.on("/snapshot", HTTP_GET, []() {
        if (!cameraReady) {
          server.send(503, "text/plain", "Cam Not Ready");
          return;
        }

        camera_fb_t *fb = esp_camera_fb_get();
        if (fb) {
          esp_camera_fb_return(fb);
        }

        fb = esp_camera_fb_get();
        if (!fb) {
          server.send(500, "text/plain", "Cam Fail");
          return;
        }

        server.sendHeader("Content-Disposition", "inline; filename=snap.jpg");
        server.send_P(200, "image/jpeg", (const char *)fb->buf, fb->len);
        esp_camera_fb_return(fb);
      });

      server.on("/logs", HTTP_GET, []() {
        if (!sdOk) {
          server.send(500, "text/plain", "SD Fail");
          return;
        }
        File file = SD_MMC.open(DEBUG_LOG, FILE_READ);
        if (!file) {
          server.send(404, "text/plain", "Log empty");
          return;
        }
        server.streamFile(file, "text/plain");
        file.close();
      });

      server.begin();

      config.api_key = API_KEY;
      auth.user.email = FIREBASE_USER_EMAIL;
      auth.user.password = FIREBASE_USER_PASSWORD;
      fbdo.setResponseSize(2048);
      Firebase.begin(&config, &auth);
      Firebase.reconnectWiFi(true);

      configTime(TIME_OFFSET, 0, "pool.ntp.org", "time.google.com");
      firebaseReady = true;
      uploadRecording(); // Check for offline videos immediately
    } else {
      writeDebug("WiFi Fail -> BLE Mode");
      startBLEMode();
    }
  }
}

void loop() {
  // BLE Credentials Verification
  if (shouldVerifyAndSave) {
    shouldVerifyAndSave = false;

    if (pStatusChar) {
      pStatusChar->setValue("TESTING");
      pStatusChar->notify();
      delay(200);
    }

    writeDebug("BLE: Verifying Creds...");

    WiFi.mode(WIFI_STA);
    WiFi.begin(wifi_ssid.c_str(), wifi_pass.c_str());

    int checkAttempts = 0;
    bool wifiVerified = false;

    while (checkAttempts < 20) {
      if (WiFi.status() == WL_CONNECTED) {
        wifiVerified = true;
        break;
      }
      delay(500);
      checkAttempts++;
    }

    if (wifiVerified) {
      writeDebug("BLE: Success! Restarting...");
      isRestarting = true;

      preferences.begin("cam_config", false);
      preferences.putString("ssid", wifi_ssid);
      preferences.putString("pass", wifi_pass);
      preferences.putString("devid", device_id);
      preferences.putString("owner", owner_id);
      preferences.end();

      if (pStatusChar) {
        pStatusChar->setValue("SUCCESS");
        pStatusChar->notify();
        delay(500);
      }

      delay(1000);
      ESP.restart();
    } else {
      writeDebug("BLE: Failed.");
      WiFi.disconnect(true);
      WiFi.mode(WIFI_OFF);

      if (pStatusChar) {
        pStatusChar->setValue("FAILED");
        pStatusChar->notify();
      }
      wifi_ssid = "";
      wifi_pass = "";
    }
  }

  if (WiFi.status() == WL_CONNECTED) { server.handleClient(); }

  if (!ntpOk && WiFi.status() == WL_CONNECTED) {
    struct tm tm;
    if (getLocalTime(&tm)) ntpOk = true;
  }

  unsigned long now = millis();

  // --- IMPROVED: Smart Watchdog (Only runs if we expect WiFi) ---
  // Checks if we are in Station Mode AND have credentials before panicking
  if (currentState == STATE_IDLE && WiFi.getMode() == WIFI_STA && wifi_ssid.length() > 0 && millis() - lastWifiCheck > 30000) {
    lastWifiCheck = millis();
    if (WiFi.status() != WL_CONNECTED) {
      writeDebug("WiFi lost. Attempting reconnect...");
      WiFi.disconnect();
      WiFi.reconnect();
    }
  }

  // --- SELF-HEALING: Camera Health Check / Recovery ---
  // If we are connected and idle, but camera is OFF (from a previous upload crash), turn it ON.
  if (WiFi.status() == WL_CONNECTED && !cameraReady && currentState == STATE_IDLE) {
      writeDebug("Restoring camera state...");
      cameraInit();
  }

  // Daily Cleanup
  if (now - lastStorageCleanup > CLEANUP_INTERVAL) {
    lastStorageCleanup = now;
    if (currentState == STATE_IDLE && ntpOk) cleanupOldFiles();
  }

  // Motion Detection - ONLY IF CAMERA IS READY
  if (now - lastPirPoll > PIR_POLL_INTERVAL) {
    lastPirPoll = now;
    if (isArmed && cameraReady && currentState == STATE_IDLE && digitalRead(PIR_PIN) == PIR_ACTIVE_STATE) {
      delay(100);
      if (digitalRead(PIR_PIN) == PIR_ACTIVE_STATE) {
        writeDebug("Motion Detected");
        startRecording();
        currentState = STATE_RECORDING;
        motionStopTime = millis();
      }
    }
  }

  switch (currentState) {
    case STATE_WARMUP:
      if ((millis() / 1000) % 2 == 0) digitalWrite(STATUS_LED, LOW);
      else digitalWrite(STATUS_LED, HIGH);
      if (millis() - bootTime > WARMUP_TIME) {
        currentState = STATE_IDLE;
        isArmed = true;
        digitalWrite(STATUS_LED, HIGH);
        writeDebug("Armed.");
      }
      break;
    case STATE_RECORDING:
      if (digitalRead(PIR_PIN) == PIR_ACTIVE_STATE) motionStopTime = millis();
      if (millis() - motionStopTime > RECORD_EXTENSION_TIME || millis() - recordingStartTime > MAX_RECORD_TIME) {
        stopRecording();
        currentState = STATE_UPLOADING;
      } else {
        captureFrame();
      }
      break;
    case STATE_UPLOADING:
      uploadRecording();
      currentState = STATE_COOLDOWN;
      break;
    case STATE_COOLDOWN:
      if (digitalRead(PIR_PIN) != PIR_ACTIVE_STATE) {
        delay(2000);
        currentState = STATE_IDLE;
        digitalWrite(STATUS_LED, HIGH);
        writeDebug("Idle.");
      }
      break;
    default: break;
  }
}

void writeLE32(File &f, uint32_t v) {
  uint8_t b[4];
  b[0] = v & 0xFF;
  b[1] = (v >> 8) & 0xFF;
  b[2] = (v >> 16) & 0xFF;
  b[3] = (v >> 24) & 0xFF;
  f.write(b, 4);
}
void writeLE16(File &f, uint16_t v) {
  uint8_t b[2];
  b[0] = v & 0xFF;
  b[1] = (v >> 8) & 0xFF;
  f.write(b, 2);
}
void writeFourCC(File &f, const char *c) {
  f.write((const uint8_t *)c, 4);
}

void writeAviHeader(File &f) {
  writeFourCC(f, "RIFF");
  writeLE32(f, 0);
  writeFourCC(f, "AVI ");
  writeFourCC(f, "LIST");
  writeLE32(f, 192);
  writeFourCC(f, "hdrl");

  writeFourCC(f, "avih");
  writeLE32(f, 56);
  writeLE32(f, 200000);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 1);
  writeLE32(f, 0);
  writeLE32(f, 640);
  writeLE32(f, 480);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);

  writeFourCC(f, "LIST");
  writeLE32(f, 108);
  writeFourCC(f, "strl");
  writeFourCC(f, "strh");
  writeLE32(f, 52);
  writeFourCC(f, "vids");
  writeFourCC(f, "MJPG");
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 1);
  writeLE32(f, 5);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);

  writeFourCC(f, "strf");
  writeLE32(f, 40);
  writeLE32(f, 40);
  writeLE32(f, 640);
  writeLE32(f, 480);
  writeLE16(f, 1);
  writeLE16(f, 24);
  writeFourCC(f, "MJPG");
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);
  writeLE32(f, 0);

  writeFourCC(f, "LIST");
  writeLE32(f, 0);
  writeFourCC(f, "movi");
}

void startRecording() {
  if (!sdOk || !cameraReady) return;
  recordingStartTime = millis();
  currentFrameCount = 0;

  currentFilePath = generateFilename();
  aviFile = SD_MMC.open(currentFilePath.c_str(), FILE_WRITE);

  if (!aviFile) {
    writeDebug("File Fail");
    return;
  }

  writeAviHeader(aviFile);
  writeDebug("Recording: " + currentFilePath);
  
  // Status LED: OFF = Busy/Recording
  digitalWrite(STATUS_LED, LOW);
}

void captureFrame() {
  if (!aviFile || !cameraReady) return;
  camera_fb_t *fb = esp_camera_fb_get();

  if (!fb) {
    writeDebug("Cam Fail - Resetting");
    cameraDeinit();
    delay(50);
    cameraInit();
    return;
  }

  if (fb->len > 0) {
    const char ckid[4] = { '0', '0', 'd', 'c' };
    aviFile.write((const uint8_t *)ckid, 4);
    writeLE32(aviFile, fb->len);
    aviFile.write(fb->buf, fb->len);
    if (fb->len % 2) {
      uint8_t p = 0;
      aviFile.write(&p, 1);
    }
    currentFrameCount++;
  }
  esp_camera_fb_return(fb);
}

void stopRecording() {
  if (aviFile) {
    long currentSize = aviFile.position();
    aviFile.seek(4);
    writeLE32(aviFile, currentSize - 8);
    aviFile.seek(48);
    writeLE32(aviFile, currentFrameCount);
    aviFile.seek(140);
    writeLE32(aviFile, currentFrameCount);
    aviFile.seek(212);
    writeLE32(aviFile, currentSize - 220);

    aviFile.seek(currentSize);
    writeFourCC(aviFile, "idx1");
    writeLE32(aviFile, 0);

    long finalSize = aviFile.position();
    aviFile.seek(4);
    writeLE32(aviFile, finalSize - 8);

    aviFile.close();
    writeDebug("Stopped. Size: " + String(finalSize) + " Frames: " + String(currentFrameCount));
  }
  digitalWrite(STATUS_LED, HIGH);
}

void uploadRecording() {
  // 1. Basic Checks
  if (!firebaseReady) {
    writeDebug("Skipping Upload: Firebase not ready");
    return;
  }
  if (WiFi.status() != WL_CONNECTED) {
    writeDebug("Skipping Upload: No WiFi");
    return;
  }

  // 2. Pause Camera (CRITICAL: Frees up RAM for heavy upload process)
  cameraDeinit();
  delay(200);

  writeDebug("Checking SD for pending uploads...");

  // 3. Open the recordings directory
  File root = SD_MMC.open("/recordings");
  if (!root || !root.isDirectory()) {
    writeDebug("No recordings folder found");
    // If no folder, we still need to restore the camera
    cameraInit();
    return;
  }

  // 4. Iterate through all files in the folder
  while (true) {
    File file = root.openNextFile();
    
    // If no more files, we are done
    if (!file) break;

    if (!file.isDirectory()) {
      String filePath = String(file.path());
      String fileName = String(file.name());

      // Only process .avi files
      if (filePath.endsWith(".avi")) {
        writeDebug("Found pending file: " + fileName);

        // Construct remote path
        String remote = "/users/" + (owner_id == "" ? "public" : owner_id) + 
                        "/devices/" + device_id + "/videos/" + fileName;

        // Close the file handle before attempting upload (saves memory)
        file.close();

        // 5. Attempt Upload
        if (Firebase.Storage.upload(&fbdo, STORAGE_BUCKET, filePath.c_str(), mem_storage_type_sd, remote.c_str(), "video/avi")) {
          writeDebug("Upload Success! Deleting local copy.");
          
          // 6. DELETE on Success (Prevent duplicates)
          SD_MMC.remove(filePath);
          
          // Restart directory scan to ensure clean iterator state
          root.close();
          root = SD_MMC.open("/recordings");
          
          // Verify WiFi is still alive before next file
          if (WiFi.status() != WL_CONNECTED) {
             writeDebug("WiFi lost during batch upload.");
             break;
          }
          continue; 
        } else {
          writeDebug("Upload Failed: " + fbdo.errorReason());
          // If one fails, stop the batch to save power/time and try again later
          break; 
        }
      }
    }
    file.close();
  }
  
  root.close();

  // 7. Restore Camera for next motion event
  // FIX: ALWAYS restore the camera, even if WiFi was lost, so we can record the next event locally.
  writeDebug("Restoring camera after upload attempt...");
  cameraInit(); 
  
  currentFilePath = ""; // Reset global tracker
}