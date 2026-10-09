// burst_log.ino - buffered high-rate accelerometer capture.
//
// Target: Arduino Mega 2560 + MPU-6500 breakout, I2C address 0x68. The board
// is a GY-9250-style module, but WHO_AM_I reads 0x70, which the register map
// gives as MPU-6500 - an MPU-9250 would read 0x71. There is no magnetometer.
// Part of the accelerometer-calibration project, Phase 2.
//
// Why the capture is buffered rather than streamed: three axes at 500 Hz is
// about 9 kB/s of text, against roughly 11.5 kB/s available at 115200 baud.
// There is no margin, and a stalled print distorts the sample interval, which
// is the one thing a frequency measurement cannot tolerate. So each run is
// captured into SRAM at a fixed interval and printed only afterwards.
//
// Serial commands (115200 baud):
//   d   print the configuration registers
//   1   100 Hz        3   250 Hz        5   1000 Hz
//   2   200 Hz        4   500 Hz
//   f   step the accelerometer bandwidth: 92 -> 460 -> 184 -> 41 -> 20 Hz
//   g   capture SAMPLE_COUNT samples and dump them as CSV

#include <Wire.h>

static const uint8_t MPU_ADDR = 0x68;

static const uint8_t REG_SMPLRT_DIV    = 0x19;
static const uint8_t REG_CONFIG        = 0x1A;
static const uint8_t REG_GYRO_CONFIG   = 0x1B;
static const uint8_t REG_ACCEL_CONFIG  = 0x1C;
static const uint8_t REG_ACCEL_CONFIG2 = 0x1D;
static const uint8_t REG_ACCEL_XOUT_H  = 0x3B;
static const uint8_t REG_PWR_MGMT_1    = 0x6B;
static const uint8_t REG_WHO_AM_I      = 0x75;

// A_DLPF_CFG, written to ACCEL_CONFIG2 (0x1D). On this part that is the
// ACCELEROMETER's bandwidth. Register 0x1A (CONFIG) sets the bandwidth of the
// gyroscope only - on the older MPU-6050 it set both, which is where the
// earlier firmware's assumption came from. Its reset value is 0x00, so a
// sketch that never writes 0x1D leaves the accelerometer at 460 Hz.
//
// Bandwidths from the MPU-6500 Register Map rev 2.1, table in section 4.6
// (ACCEL_FCHOICE_B = 0, output rate 1 kHz throughout):
//   0 -> 460 Hz    2 -> 92 Hz    4 -> 20 Hz    6 -> 5 Hz
//   1 -> 184 Hz    3 -> 41 Hz    5 -> 10 Hz    7 -> 460 Hz
static uint8_t accelDlpf = 0x02;   // 92 Hz, changed at runtime with 'f'

// AFS_SEL = 1, that is +/-4 g, nominally 8192 counts/g. Same range as the
// static six-position calibration, so the scale factors carry over.
static const uint8_t ACCEL_RANGE = 0x08;

// 1000 samples x 3 axes x 2 bytes = 6000 bytes of the Mega's 8192 bytes of
// SRAM. Raising this will run the board out of memory.
static const uint16_t SAMPLE_COUNT = 1000;

static int16_t bufX[SAMPLE_COUNT];
static int16_t bufY[SAMPLE_COUNT];
static int16_t bufZ[SAMPLE_COUNT];

static uint16_t sampleRate  = 500;
static uint8_t  dlpfAsFound = 0xFF;

static void writeReg(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg);
  Wire.write(value);
  Wire.endTransmission();
}

static uint8_t readReg(uint8_t reg) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg);
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)MPU_ADDR, (uint8_t)1);
  return (uint8_t)Wire.read();
}

// Read all six accelerometer bytes in one burst, so the three axes come from
// the same instant. The high and low bytes are kept in named variables: the
// order in which the two halves of an expression like (read() << 8 | read())
// are evaluated is not defined in C++, and getting it backwards silently
// corrupts every reading.
//
// Returns false if the transfer failed. This matters more than it looks: on a
// failed read Wire.read() hands back -1, which becomes 0xFF, so a dropped
// transfer would otherwise appear in the data as a plausible-looking number
// with nothing to mark it. On the shake table the sensor hangs off jumper
// wires that are being shaken, so a bus glitch is a real possibility and the
// count belongs in the log beside the data.
static bool readAccel(int16_t &ax, int16_t &ay, int16_t &az) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(REG_ACCEL_XOUT_H);
  if (Wire.endTransmission(false) != 0) {
    return false;
  }
  if (Wire.requestFrom((uint8_t)MPU_ADDR, (uint8_t)6) != 6) {
    return false;
  }

  uint8_t b[6];
  for (uint8_t k = 0; k < 6; k++) {
    b[k] = (uint8_t)Wire.read();
  }

  ax = (int16_t)(((uint16_t)b[0] << 8) | b[1]);
  ay = (int16_t)(((uint16_t)b[2] << 8) | b[3]);
  az = (int16_t)(((uint16_t)b[4] << 8) | b[5]);
  return true;
}

// Bandwidth in Hz for an ACCEL_CONFIG2 value, so the log says what the
// filter actually was rather than leaving a raw register value to decode.
static uint16_t accelBandwidth(uint8_t cfg) {
  if (cfg & 0x08) {
    return 1130;              // ACCEL_FCHOICE_B set: DLPF bypassed
  }
  switch (cfg & 0x07) {
    case 0: return 460;
    case 1: return 184;
    case 2: return 92;
    case 3: return 41;
    case 4: return 20;
    case 5: return 10;
    case 6: return 5;
    default: return 460;
  }
}

static void printConfig() {
  Serial.print(F("WHO_AM_I        0x"));
  Serial.print(readReg(REG_WHO_AM_I), HEX);
  Serial.println(F("   (0x70 = MPU-6500, 0x71 = MPU-9250, 0x73 = MPU-9255)"));

  Serial.print(F("SMPLRT_DIV 0x19 0x"));
  Serial.println(readReg(REG_SMPLRT_DIV), HEX);

  Serial.print(F("CONFIG     0x1A 0x"));
  Serial.print(readReg(REG_CONFIG), HEX);
  Serial.println(F("   (gyro bandwidth only)"));

  Serial.print(F("GYRO_CFG   0x1B 0x"));
  Serial.println(readReg(REG_GYRO_CONFIG), HEX);

  Serial.print(F("ACCEL_CFG  0x1C 0x"));
  Serial.print(readReg(REG_ACCEL_CONFIG), HEX);
  Serial.println(F("   (0x08 = +/-4 g)"));

  uint8_t cfg2 = readReg(REG_ACCEL_CONFIG2);
  Serial.print(F("ACCEL_CFG2 0x1D 0x"));
  Serial.print(cfg2, HEX);
  Serial.print(F("   accelerometer bandwidth "));
  Serial.print(accelBandwidth(cfg2));
  Serial.println(F(" Hz"));

  // Only meaningful on the first run after a power cycle. Reconnecting the
  // serial monitor pulses DTR and resets the board, so on every later run
  // this just reports the value this sketch itself wrote a moment earlier.
  Serial.print(F("  value found before this sketch wrote it: 0x"));
  Serial.print(dlpfAsFound, HEX);
  Serial.print(F(" ("));
  Serial.print(accelBandwidth(dlpfAsFound));
  Serial.println(F(" Hz) - only valid on the first run after a power cycle"));

  Serial.print(F("sample rate     "));
  Serial.print(sampleRate);
  Serial.println(F(" Hz"));
}

static void capture() {
  const uint32_t interval = 1000000UL / sampleRate;

  uint32_t next   = micros();
  uint32_t tFirst = 0;
  uint32_t tLast  = 0;
  uint16_t late   = 0;
  uint16_t i2cErr = 0;

  for (uint16_t i = 0; i < SAMPLE_COUNT; i++) {
    // Signed difference, so this still works across the micros() rollover.
    while ((int32_t)(micros() - next) < 0) {
      // wait for the slot
    }
    uint32_t now = micros();

    // Count slots missed by more than a quarter interval. A nonzero count
    // means the requested rate was not actually achieved.
    if ((int32_t)(now - next) > (int32_t)(interval / 4)) {
      late++;
    }
    if (i == 0) {
      tFirst = now;
    }
    if (i == SAMPLE_COUNT - 1) {
      tLast = now;
    }

    if (!readAccel(bufX[i], bufY[i], bufZ[i])) {
      i2cErr++;
    }
    next += interval;
  }

  // The true rate, measured rather than assumed. Every frequency the analysis
  // reports is scaled by this number, so it must come from the hardware.
  float actual = 1000000.0f * (float)(SAMPLE_COUNT - 1) / (float)(tLast - tFirst);

  Serial.print(F("# rate_hz="));
  Serial.print(actual, 3);
  Serial.print(F(" requested_hz="));
  Serial.print(sampleRate);
  Serial.print(F(" accel_dlpf=0x"));
  Serial.print(readReg(REG_ACCEL_CONFIG2), HEX);
  Serial.print(F(" accel_bw_hz="));
  Serial.print(accelBandwidth(readReg(REG_ACCEL_CONFIG2)));
  Serial.print(F(" accel_range=0x"));
  Serial.print(readReg(REG_ACCEL_CONFIG), HEX);
  Serial.print(F(" n="));
  Serial.print(SAMPLE_COUNT);
  Serial.print(F(" late="));
  Serial.print(late);
  Serial.print(F(" i2c_err="));
  Serial.println(i2cErr);

  Serial.println(F("i,ax,ay,az"));
  for (uint16_t i = 0; i < SAMPLE_COUNT; i++) {
    Serial.print(i);
    Serial.print(',');
    Serial.print(bufX[i]);
    Serial.print(',');
    Serial.print(bufY[i]);
    Serial.print(',');
    Serial.println(bufZ[i]);
  }
  Serial.println(F("# end"));
}

void setup() {
  Serial.begin(115200);
  Wire.begin();
  Wire.setClock(400000);
  delay(50);

  // Wake the device without resetting it, so whatever the previous sketch
  // left in the configuration registers is still there to be read.
  writeReg(REG_PWR_MGMT_1, 0x00);
  delay(50);

  dlpfAsFound = readReg(REG_ACCEL_CONFIG2);

  writeReg(REG_SMPLRT_DIV, 0x00);
  writeReg(REG_ACCEL_CONFIG, ACCEL_RANGE);
  writeReg(REG_ACCEL_CONFIG2, accelDlpf);
  delay(10);

  Serial.println();
  Serial.println(F("burst_log ready"));
  printConfig();
  Serial.println(F("commands: d = registers, 1..5 = sample rate,"));
  Serial.println(F("          f = cycle accelerometer bandwidth, g = capture"));
}

void loop() {
  if (!Serial.available()) {
    return;
  }

  char c = (char)Serial.read();
  switch (c) {
    case 'd': printConfig(); break;
    case 'f': {
      // Ordered so that one press takes the default 92 Hz straight to
      // 460 Hz, the pair worth comparing: capturing the same still sensor at
      // both and comparing standard deviations is the cheapest check that
      // this register does what the datasheet says, since noise should fall
      // as the square root of the bandwidth ratio. Further presses continue
      // 184 -> 41 -> 20 -> back to 92; a board reset also returns to 92.
      static const uint8_t order[] = {0x02, 0x00, 0x01, 0x03, 0x04};
      uint8_t next = 0x00;
      for (uint8_t i = 0; i < 5; i++) {
        if (order[i] == accelDlpf) {
          next = order[(i + 1) % 5];
        }
      }
      accelDlpf = next;
      writeReg(REG_ACCEL_CONFIG2, accelDlpf);
      delay(10);
      Serial.print(F("accel bandwidth "));
      Serial.print(accelBandwidth(accelDlpf));
      Serial.print(F(" Hz (ACCEL_CONFIG2 = 0x"));
      Serial.print(accelDlpf, HEX);
      Serial.println(F(")"));
      break;
    }
    case '1': sampleRate = 100;  Serial.println(F("rate 100 Hz"));  break;
    case '2': sampleRate = 200;  Serial.println(F("rate 200 Hz"));  break;
    case '3': sampleRate = 250;  Serial.println(F("rate 250 Hz"));  break;
    case '4': sampleRate = 500;  Serial.println(F("rate 500 Hz"));  break;
    case '5': sampleRate = 1000; Serial.println(F("rate 1000 Hz")); break;
    case 'g': capture(); break;
    default: break;
  }
}
