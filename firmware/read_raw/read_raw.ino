// read_raw.ino
// Continuously prints raw accelerometer counts on all three axes.

#include <Wire.h>

const uint8_t MPU_ADDR       = 0x68;
const uint8_t REG_PWR_MGMT   = 0x6B;
const uint8_t REG_CONFIG     = 0x1A;
const uint8_t REG_ACCEL_CFG  = 0x1C;
const uint8_t REG_ACCEL_XOUT = 0x3B;

void writeRegister(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg);
  Wire.write(value);
  Wire.endTransmission();
}

void setup() {
  Serial.begin(115200);
  Wire.begin();
  Wire.setClock(400000);

  writeRegister(REG_PWR_MGMT,  0x00);   // wake the chip up
  writeRegister(REG_CONFIG,    0x03);   // digital low pass filter, 44 Hz
  writeRegister(REG_ACCEL_CFG, 0x08);   // AFS_SEL = 1, range +/-4g

  Serial.println("ax\tay\taz");
}

void loop() {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(REG_ACCEL_XOUT);
  Wire.endTransmission(false);
  Wire.requestFrom((int)MPU_ADDR, 6, true);

  int16_t ax = (Wire.read() << 8) | Wire.read();
  int16_t ay = (Wire.read() << 8) | Wire.read();
  int16_t az = (Wire.read() << 8) | Wire.read();

  Serial.print(ax); Serial.print('\t');
  Serial.print(ay); Serial.print('\t');
  Serial.println(az);

  delay(200);
}