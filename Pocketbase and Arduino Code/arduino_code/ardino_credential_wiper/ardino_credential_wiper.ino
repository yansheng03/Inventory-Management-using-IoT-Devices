#include <Preferences.h>

Preferences preferences;

void setup() {
  Serial.begin(115200);
  while (!Serial); // Wait for Serial Monitor to open

  Serial.println("Starting credential wipe...");

  // This namespace MUST match the one in your main sketch
  preferences.begin("fridge-creds", false);
  
  // Clear all saved keys in this "fridge-creds" namespace
  preferences.clear();
  
  // End the preferences session
  preferences.end();

  Serial.println("-------------------------------------------------");
  Serial.println("All saved WiFi credentials have been WIPED.");
  Serial.println("You can now upload your main Arduino project sketch.");
  Serial.println("-------------------------------------------------");
}

void loop() {
  // Do nothing.
  delay(1000);
}