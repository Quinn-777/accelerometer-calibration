// i2c_scan.ino
// Scans the I2C bus and prints the address of every device found.
// Expect to find 0x68 (MPU6050 with AD0 low).

#include <Wire.h>

void setup() {
  Serial.begin(115200);
  Wire.begin();
  delay(1000);

  Serial.println("Scanning I2C bus...");
  int found = 0;

  for (uint8_t addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.print("Device found at 0x");
      if (addr < 16) Serial.print("0");
      Serial.println(addr, HEX);
      found++;
    }
  }

  if (found == 0) Serial.println("No devices found. Check wiring.");
  else Serial.print("Done. Devices found: "), Serial.println(found);
}

void loop() { }