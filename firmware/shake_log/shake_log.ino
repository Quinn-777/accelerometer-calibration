// shake_log.ino - shake table drive + buffered accelerometer capture, in one
// sketch. Part of the accelerometer-calibration project, Phase 2.
//
// Target: Arduino Mega 2560 + DRV8825 (1/8 microstep) + NEMA 17, and the
// MPU-6500 breakout on I2C at 0x68.
//
// This is motor_test.ino and burst_log.ino joined together, because they
// cannot run as two sketches: uploading the second resets the board and stops
// the motor. It works as one sketch because the motor needs no CPU at all
// once it is at speed - Timer1 toggles the STEP pin in hardware - so the main
// loop is free to sample the sensor on a fixed schedule.
//
// WIRING
//   DRV8825 STEP -> pin 11 (OC1A)   DIR -> pin 4   EN -> pin 5
//   RST + SLP -> 5V   M0, M1 -> 5V   M2 -> GND   (1/8 microstep)
//   VMOT/GND -> 24 V with 100 uF across them   driver GND -> Mega GND
//   Sensor VCC -> 5V   GND -> GND   SCL -> 21   SDA -> 20
//
// SERIAL COMMANDS (115200 baud, line ending "Newline")
//   3.5      ramp the crank to 3.5 turns per second (any number)
//   0        ramp down and switch the driver off
//   x        stop at once, driver off
//   g        capture SAMPLE_COUNT samples and print them as CSV. Allowed when
//            the motor is stopped, or when it has been at its set speed for
//            SETTLE_MS - never during a ramp.
//   r500     sample rate: r100, r200, r250 or r500 (Hz)
//   b        step the accelerometer bandwidth: 92 -> 460 -> 184 -> 41 -> 20
//   d        print the sensor registers and the current settings
//
// OUTPUT
//   Each capture starts with one "# rate_hz=..." line and ends with "# end",
//   the same record format as burst_log, so analysis/spectrum.py still reads
//   it. New fields on the header line:
//     shaft_hz   the crank frequency the timer is ACTUALLY running at,
//                16 MHz / (2 (OCR1A + 1) x 1600) - not the number typed in
//     ocr1a      the register value it came from
//     crank_mm   CRANK_MM below - the MEASURED throw, not the design value
//     a_pk_ms2   CRANK_MM x (2 pi shaft_hz)^2, the peak acceleration the
//                table should produce, in m/s^2
//   Copy everything from "# rate_hz" to "# end" into a .csv file in data/.
//
// BEFORE EACH SESSION: set CRANK_MM to the measured throw of the crank that
// is fitted, and upload. 2026-10-23, 13 mm crank: A = 13.60 +/- 0.18 mm.

#include <Wire.h>

// ---- crank -----------------------------------------------------------------
const float CRANK_MM = 13.60;     // MEASURED throw of the fitted crank
const float MAX_G    = 3.5;       // keep the peak under the sensor's +/-4 g

// ---- motor -----------------------------------------------------------------
const uint8_t  PIN_STEP = 11;     // OC1A on the Mega 2560 - must be 11
const uint8_t  PIN_DIR  = 4;
const uint8_t  PIN_EN   = 5;      // LOW = driver on
const float    CPU_HZ   = 16000000.0;
const float    PULSES_PER_REV = 200.0 * 8.0;   // 200 steps x 1/8 microstep

const float    F_START        = 0.5;    // start and stop speed, turns/s
const float    RAMP_HZ_PER_S  = 2.0;
const uint16_t RAMP_TICK_MS   = 20;
const uint16_t SETTLE_MS      = 2000;   // wait this long at speed before 'g'

// ---- sensor (as burst_log) -------------------------------------------------
static const uint8_t MPU_ADDR = 0x68;
static const uint8_t REG_SMPLRT_DIV    = 0x19;
static const uint8_t REG_CONFIG        = 0x1A;
static const uint8_t REG_GYRO_CONFIG   = 0x1B;
static const uint8_t REG_ACCEL_CONFIG  = 0x1C;
static const uint8_t REG_ACCEL_CONFIG2 = 0x1D;
static const uint8_t REG_ACCEL_XOUT_H  = 0x3B;
static const uint8_t REG_PWR_MGMT_1    = 0x6B;
static const uint8_t REG_WHO_AM_I      = 0x75;
static const uint8_t ACCEL_RANGE = 0x08;     // +/-4 g, as the six-position cal
static uint8_t accelDlpf = 0x02;             // 92 Hz

// 1000 x 3 axes x 2 bytes = 6000 of the Mega's 8192 bytes. Do not raise.
static const uint16_t SAMPLE_COUNT = 1000;
static int16_t bufX[SAMPLE_COUNT];
static int16_t bufY[SAMPLE_COUNT];
static int16_t bufZ[SAMPLE_COUNT];
static uint16_t sampleRate = 500;

// ---- motor state -----------------------------------------------------------
volatile uint16_t pendingOcr = 0;
volatile bool     ocrPending = false;
uint16_t ocrNow  = 0;
float    fNow    = 0.0;       // what the timer is set to (0 = stopped)
float    fTarget = 0.0;
float    fMax    = 0.0;
bool     running = false;
bool     atSpeed = false;     // reached the target and not ramping
bool     readyReported = false;
unsigned long atSpeedSince = 0;
unsigned long lastTick = 0;

// ============================================================================
// Motor: Timer1 in CTC mode toggles pin 11 at every match with OCR1A, so the
// step rate is 16 MHz / (2 (OCR1A + 1)) and needs no CPU. OCR1A is only
// changed inside the compare interrupt, right after the counter has reset to
// 0; written at any other moment the new value can fall below the running
// count, and the counter would run on to 65535 before the next step.
// ============================================================================

uint16_t ocrFor(float f) {
    float ocr = CPU_HZ / (2.0 * f * PULSES_PER_REV) - 1.0;
    if (ocr < 1.0)     ocr = 1.0;
    if (ocr > 65535.0) ocr = 65535.0;
    return (uint16_t)(ocr + 0.5);
}

float freqFor(uint16_t ocr) {
    return CPU_HZ / (2.0 * ((float)ocr + 1.0)) / PULSES_PER_REV;
}

ISR(TIMER1_COMPA_vect) {
    if (ocrPending) {
        OCR1A = pendingOcr;
        ocrPending = false;
    }
    TIMSK1 &= ~_BV(OCIE1A);     // only runs during a ramp, never in a capture
}

void setOcr(uint16_t ocr) {
    noInterrupts();
    pendingOcr = ocr;
    ocrPending = true;
    TIFR1  = _BV(OCF1A);
    TIMSK1 |= _BV(OCIE1A);
    interrupts();
    ocrNow = ocr;
    fNow = freqFor(ocr);
}

void startTimer(float f) {
    uint16_t ocr = ocrFor(f);
    digitalWrite(PIN_EN, LOW);
    delay(5);
    noInterrupts();
    TCCR1A = 0;
    TCCR1B = 0;
    TCNT1  = 0;
    OCR1A  = ocr;
    TCCR1A = _BV(COM1A0);                // toggle OC1A on match
    TCCR1B = _BV(WGM12) | _BV(CS10);     // CTC, no prescaler
    interrupts();
    ocrNow = ocr;
    fNow = freqFor(ocr);
    running = true;
}

void stopTimer() {
    noInterrupts();
    TCCR1B = 0;
    TCCR1A = 0;
    TIMSK1 &= ~_BV(OCIE1A);
    ocrPending = false;
    interrupts();
    digitalWrite(PIN_STEP, LOW);
    digitalWrite(PIN_EN, HIGH);
    running = false;
    atSpeed = false;
    fNow = 0.0;
    fTarget = 0.0;
    ocrNow = 0;
}

float peakG(float f) {
    float w = 2.0 * PI * f;
    return CRANK_MM / 1000.0 * w * w / 9.80665;
}

// One ramp step per RAMP_TICK_MS. Register values are compared, not floats:
// the timer can only produce 16 MHz divided by an integer.
void rampTick() {
    if (!running) return;
    unsigned long now = millis();
    if (now - lastTick < RAMP_TICK_MS) return;
    lastTick = now;

    float goal = (fTarget > 0.0) ? fTarget : F_START;
    uint16_t ocrGoal = ocrFor(goal);

    if (ocrNow != ocrGoal) {
        atSpeed = false;
        float stepHz = RAMP_HZ_PER_S * RAMP_TICK_MS / 1000.0;
        float fNext = (fNow < goal) ? min(goal, fNow + stepHz)
                                    : max(goal, fNow - stepHz);
        uint16_t ocrNext = ocrFor(fNext);
        if (ocrNext == ocrNow)
            ocrNext = (ocrGoal < ocrNow) ? ocrNow - 1 : ocrNow + 1;
        setOcr(ocrNext);
    } else if (fTarget > 0.0) {
        if (!atSpeed) {
            atSpeed = true;
            atSpeedSince = now;
            readyReported = false;
            Serial.print(F("Reached "));
            Serial.print(fNow, 4);
            Serial.print(F(" Hz (OCR1A "));
            Serial.print(ocrNow);
            Serial.print(F("), peak "));
            Serial.print(peakG(fNow), 3);
            Serial.println(F(" g. Settling..."));
        } else if (!readyReported && now - atSpeedSince >= SETTLE_MS) {
            readyReported = true;
            Serial.println(F("Steady. Type g to capture."));
        }
    } else {
        stopTimer();
        Serial.println(F("Stopped, driver off."));
    }
}

// ============================================================================
// Sensor (unchanged from burst_log)
// ============================================================================

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

// All six bytes in one burst so the three axes are from the same instant.
// Returns false on a failed transfer, which is counted in the log rather
// than written into the data as a plausible-looking 0xFF.
static bool readAccel(int16_t &ax, int16_t &ay, int16_t &az) {
    Wire.beginTransmission(MPU_ADDR);
    Wire.write(REG_ACCEL_XOUT_H);
    if (Wire.endTransmission(false) != 0) return false;
    if (Wire.requestFrom((uint8_t)MPU_ADDR, (uint8_t)6) != 6) return false;
    uint8_t b[6];
    for (uint8_t k = 0; k < 6; k++) b[k] = (uint8_t)Wire.read();
    ax = (int16_t)(((uint16_t)b[0] << 8) | b[1]);
    ay = (int16_t)(((uint16_t)b[2] << 8) | b[3]);
    az = (int16_t)(((uint16_t)b[4] << 8) | b[5]);
    return true;
}

static uint16_t accelBandwidth(uint8_t cfg) {
    if (cfg & 0x08) return 1130;
    switch (cfg & 0x07) {
        case 0: return 460;  case 1: return 184;  case 2: return 92;
        case 3: return 41;   case 4: return 20;   case 5: return 10;
        case 6: return 5;    default: return 460;
    }
}

static void printConfig() {
    Serial.print(F("WHO_AM_I 0x"));
    Serial.print(readReg(REG_WHO_AM_I), HEX);
    Serial.println(F("  (0x70 = MPU-6500)"));
    Serial.print(F("ACCEL_CFG 0x"));
    Serial.print(readReg(REG_ACCEL_CONFIG), HEX);
    Serial.println(F("  (0x08 = +/-4 g)"));
    uint8_t cfg2 = readReg(REG_ACCEL_CONFIG2);
    Serial.print(F("ACCEL_CFG2 0x"));
    Serial.print(cfg2, HEX);
    Serial.print(F("  bandwidth "));
    Serial.print(accelBandwidth(cfg2));
    Serial.println(F(" Hz"));
    Serial.print(F("sample rate "));
    Serial.print(sampleRate);
    Serial.println(F(" Hz"));
    Serial.print(F("crank "));
    Serial.print(CRANK_MM, 2);
    Serial.print(F(" mm, limit "));
    Serial.print(fMax, 2);
    Serial.println(F(" Hz"));
    Serial.print(F("motor "));
    if (running) {
        Serial.print(fNow, 4);
        Serial.println(atSpeed ? F(" Hz, at speed") : F(" Hz, ramping"));
    } else {
        Serial.println(F("stopped"));
    }
}

static void capture() {
    if (running && !(atSpeed && millis() - atSpeedSince >= SETTLE_MS)) {
        Serial.println(F("Not yet: wait for \"Steady\" before capturing."));
        return;
    }
    // At this point no ramp is in progress, so the Timer1 interrupt is off and
    // the only thing sharing the CPU with the sampling is the Wire library.
    float shaftHz = running ? fNow : 0.0;
    uint16_t ocr  = running ? ocrNow : 0;

    const uint32_t interval = 1000000UL / sampleRate;
    uint32_t next = micros(), tFirst = 0, tLast = 0;
    uint16_t late = 0, i2cErr = 0;

    for (uint16_t i = 0; i < SAMPLE_COUNT; i++) {
        while ((int32_t)(micros() - next) < 0) { }
        uint32_t now = micros();
        if ((int32_t)(now - next) > (int32_t)(interval / 4)) late++;
        if (i == 0) tFirst = now;
        if (i == SAMPLE_COUNT - 1) tLast = now;
        if (!readAccel(bufX[i], bufY[i], bufZ[i])) i2cErr++;
        next += interval;
    }
    float actual = 1000000.0f * (float)(SAMPLE_COUNT - 1) / (float)(tLast - tFirst);
    float w = 2.0 * PI * shaftHz;

    Serial.print(F("# rate_hz="));        Serial.print(actual, 3);
    Serial.print(F(" requested_hz="));    Serial.print(sampleRate);
    Serial.print(F(" accel_dlpf=0x"));    Serial.print(readReg(REG_ACCEL_CONFIG2), HEX);
    Serial.print(F(" accel_bw_hz="));     Serial.print(accelBandwidth(readReg(REG_ACCEL_CONFIG2)));
    Serial.print(F(" accel_range=0x"));   Serial.print(readReg(REG_ACCEL_CONFIG), HEX);
    Serial.print(F(" n="));               Serial.print(SAMPLE_COUNT);
    Serial.print(F(" late="));            Serial.print(late);
    Serial.print(F(" i2c_err="));         Serial.print(i2cErr);
    Serial.print(F(" shaft_hz="));        Serial.print(shaftHz, 5);
    Serial.print(F(" ocr1a="));           Serial.print(ocr);
    Serial.print(F(" crank_mm="));        Serial.print(CRANK_MM, 3);
    Serial.print(F(" a_pk_ms2="));        Serial.println(CRANK_MM / 1000.0 * w * w, 4);

    Serial.println(F("i,ax,ay,az"));
    for (uint16_t i = 0; i < SAMPLE_COUNT; i++) {
        Serial.print(i);       Serial.print(',');
        Serial.print(bufX[i]); Serial.print(',');
        Serial.print(bufY[i]); Serial.print(',');
        Serial.println(bufZ[i]);
    }
    Serial.println(F("# end"));
}

// ============================================================================
// Commands
// ============================================================================

void handleLine(char *s) {
    while (*s == ' ') s++;
    if (*s == 0) return;
    char c = s[0];

    if (c == 'x' || c == 'X') { stopTimer(); Serial.println(F("STOPPED, driver off.")); return; }
    if (c == 'g') { capture(); return; }
    if (c == 'd') { printConfig(); return; }
    if (c == 'b') {
        static const uint8_t order[] = {0x02, 0x00, 0x01, 0x03, 0x04};
        uint8_t nxt = 0x00;
        for (uint8_t i = 0; i < 5; i++) if (order[i] == accelDlpf) nxt = order[(i + 1) % 5];
        accelDlpf = nxt;
        writeReg(REG_ACCEL_CONFIG2, accelDlpf);
        delay(10);
        Serial.print(F("accel bandwidth "));
        Serial.print(accelBandwidth(accelDlpf));
        Serial.println(F(" Hz"));
        return;
    }
    if (c == 'r') {
        long r = atol(s + 1);
        if (r == 100 || r == 200 || r == 250 || r == 500) {
            sampleRate = (uint16_t)r;
            Serial.print(F("sample rate "));
            Serial.print(sampleRate);
            Serial.println(F(" Hz"));
        } else {
            Serial.println(F("Use r100, r200, r250 or r500."));
        }
        return;
    }
    if ((c >= '0' && c <= '9') || c == '.') {
        float f = atof(s);
        if (f > fMax) {
            Serial.print(F("Refused: above "));
            Serial.print(fMax, 2);
            Serial.println(F(" Hz for this crank."));
            return;
        }
        if (f > 0.0 && f < F_START) f = F_START;
        fTarget = f;
        atSpeed = false;
        if (f > 0.0 && !running) startTimer(F_START);
        Serial.println(f > 0.0 ? F("Ramping.") : F("Ramping down."));
        return;
    }
    Serial.println(F("Commands: <Hz>, 0, x, g, r<rate>, b, d"));
}

void setup() {
    pinMode(PIN_EN, OUTPUT);   digitalWrite(PIN_EN, HIGH);
    pinMode(PIN_STEP, OUTPUT); digitalWrite(PIN_STEP, LOW);
    pinMode(PIN_DIR, OUTPUT);  digitalWrite(PIN_DIR, HIGH);

    Serial.begin(115200);
    Wire.begin();
    // 100 kHz, not 400 kHz (changed 2026-10-23). The sensor rides on the
    // carriage at the end of ~30 cm of jumper wire that is being shaken; at
    // 400 kHz the 5 Hz run showed bit errors (readings of -1 and -16385)
    // as well as failed transfers. A 6-byte read takes about 1 ms at
    // 100 kHz, which fits the 2 ms slot at 500 Hz - but not 1000 Hz, so
    // r1000 is no longer offered.
    Wire.setClock(100000);
    // Without a timeout, the AVR Wire library waits forever if SDA or SCL is
    // stuck - a loose or shaken sensor wire can do that - and the whole
    // sketch freezes, motor control included. With it, a failed transfer
    // just returns an error, which is counted (i2c_err) like any other.
    Wire.setWireTimeout(3000, true);   // 3 ms, reset the bus on timeout
    delay(50);
    writeReg(REG_PWR_MGMT_1, 0x00);
    delay(50);
    writeReg(REG_SMPLRT_DIV, 0x00);
    writeReg(REG_ACCEL_CONFIG, ACCEL_RANGE);
    writeReg(REG_ACCEL_CONFIG2, accelDlpf);
    delay(10);

    fMax = sqrt(MAX_G * 9.80665 / (CRANK_MM / 1000.0)) / (2.0 * PI);

    Serial.println();
    Serial.println(F("shake_log ready"));
    if (readReg(REG_WHO_AM_I) != 0x70) {
        Serial.println(F("WARNING: sensor not responding (WHO_AM_I is not 0x70)."));
        Serial.println(F("Check SDA -> 20, SCL -> 21, VCC, GND. The motor still works."));
    }
    printConfig();
    Serial.println(F("Commands: <Hz>, 0, x, g, r<rate>, b, d"));
}

void loop() {
    static char line[24];
    static uint8_t len = 0;
    while (Serial.available()) {
        char ch = (char)Serial.read();
        if (ch == '\n' || ch == '\r') {
            line[len] = 0;
            handleLine(line);
            len = 0;
        } else if (len < sizeof(line) - 1) {
            line[len++] = ch;
        }
    }
    rampTick();
}
