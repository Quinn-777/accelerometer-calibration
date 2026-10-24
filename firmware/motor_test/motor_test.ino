// motor_test.ino - first powered run of the shake table: motor only, no sensor.
//
// Target: Arduino Mega 2560 + DRV8825 + NEMA 17 (200 full steps per rev).
// Part of the accelerometer-calibration project, Phase 2.
//
// WIRING (everything unpowered while you wire it)
//   DRV8825 STEP  -> Mega pin 11   (Timer1 output OC1A - must be pin 11)
//   DRV8825 DIR   -> Mega pin 4
//   DRV8825 EN    -> Mega pin 5    (LOW = driver on, HIGH = off)
//   RESET + SLEEP -> Mega 5V       (joined together)
//   M0, M1 -> 5V, M2 -> GND        = 1/8 microstep, must match MICROSTEPS
//   VMOT / GND    -> 24 V supply, 100 uF cap across them right at the board
//   driver GND    -> Mega GND      (common ground)
//   A1 A2 B1 B2   -> motor coils
//   FAULT not connected. The DRV8825 has no VDD pin.
//
// HOW TO USE
//   Serial Monitor at 115200 baud, line ending "Newline". Type:
//     a number, e.g. 1  or  3.5   ramp the crank to that many turns per second
//     0                            ramp down, then switch the driver off
//     x                            stop at once and switch off (if anything
//                                  sounds or looks wrong)
//   Every change prints the frequency the timer is ACTUALLY running at.
//   Requests above the limit for the fitted crank are refused (see CRANK_MM).
//
// HOW IT WORKS
//   The step pulses come from Timer1 in hardware: in CTC mode the timer
//   toggles pin 11 every time it counts up to OCR1A, so the pulse rate is set
//   by one register and does not depend on what the code is doing. That is
//   why the shaft frequency is known exactly - it is 16 MHz divided by
//   integers - and why the main loop is free for logging later.
//   OCR1A is only ever changed inside the compare-match interrupt, right
//   after the counter has reset to 0. Writing it at any other moment can put
//   the new value below the running count, and the counter would then run on
//   to 65535 before matching again: a 4 ms gap in the pulses at full speed,
//   enough to make the motor lose its place.

const uint8_t  PIN_STEP = 11;     // OC1A on the Mega 2560
const uint8_t  PIN_DIR  = 4;
const uint8_t  PIN_EN   = 5;

const uint16_t STEPS_PER_REV = 200;
const uint8_t  MICROSTEPS    = 8;          // M0 high, M1 high, M2 low
const float    CPU_HZ        = 16000000.0;
const float    PULSES_PER_REV = (float)STEPS_PER_REV * MICROSTEPS;   // 1600

// The crank on the motor now: 13, 9 or 6. Sets the speed limit so the peak
// acceleration A * (2 pi f)^2 stays under MAX_G - the sensor reads +/-4 g.
const float CRANK_MM = 13.0;
const float MAX_G    = 3.5;

const float F_START       = 0.5;    // turns/s: start and stop speed
const float RAMP_HZ_PER_S = 2.0;    // how fast the speed changes
const unsigned long RAMP_TICK_MS = 20;

volatile uint16_t pendingOcr = 0;
volatile bool     ocrPending = false;

float fNow    = 0.0;    // frequency the timer is set to (0 = stopped)
uint16_t ocrNow = 0;    // and the register value that gives it
bool  reachedReported = false;
float fTarget = 0.0;
float fMax    = 0.0;
bool  running = false;
unsigned long lastTick = 0;

// ---- timer helpers ---------------------------------------------------------

uint16_t ocrFor(float f) {
    // pin 11 toggles on every match, so one step pulse = two matches
    float ocr = CPU_HZ / (2.0 * f * PULSES_PER_REV) - 1.0;
    if (ocr < 1.0)     ocr = 1.0;
    if (ocr > 65535.0) ocr = 65535.0;
    return (uint16_t)(ocr + 0.5);
}

float freqFor(uint16_t ocr) {
    return CPU_HZ / (2.0 * ((float)ocr + 1.0)) / PULSES_PER_REV;
}

ISR(TIMER1_COMPA_vect) {
    // Runs right after a match, with TCNT1 just reset to 0: the one safe
    // moment to change OCR1A. Then the interrupt switches itself off again.
    if (ocrPending) {
        OCR1A = pendingOcr;
        ocrPending = false;
    }
    TIMSK1 &= ~_BV(OCIE1A);
}

// Changes the speed of a running timer, safely. Returns the actual frequency.
float setFreq(float f) {
    uint16_t ocr = ocrFor(f);
    noInterrupts();
    pendingOcr = ocr;
    ocrPending = true;
    TIFR1  = _BV(OCF1A);        // clear any old match flag first
    TIMSK1 |= _BV(OCIE1A);      // apply at the next match
    interrupts();
    return freqFor(ocr);
}

void startTimer(float f) {
    uint16_t ocr = ocrFor(f);
    digitalWrite(PIN_EN, LOW);  // driver on, holding the motor
    delay(5);
    noInterrupts();
    TCCR1A = 0;
    TCCR1B = 0;
    TCNT1  = 0;
    OCR1A  = ocr;
    TCCR1A = _BV(COM1A0);                // toggle OC1A on match
    TCCR1B = _BV(WGM12) | _BV(CS10);     // CTC mode, no prescaler: starts now
    interrupts();
    ocrNow = ocr;
    fNow = freqFor(ocr);
    running = true;
}

void stopTimer() {
    noInterrupts();
    TCCR1B = 0;                 // clock off
    TCCR1A = 0;                 // pin 11 back to a normal output
    TIMSK1 &= ~_BV(OCIE1A);
    ocrPending = false;
    interrupts();
    digitalWrite(PIN_STEP, LOW);
    digitalWrite(PIN_EN, HIGH); // driver off: the motor can be turned by hand
    running = false;
    fNow = 0.0;
    fTarget = 0.0;
}

// ---- commands ----------------------------------------------------------------

void report(const char *what) {
    Serial.print(what);
    Serial.print("  set ");
    Serial.print(fNow, 4);
    Serial.print(" Hz  (target ");
    Serial.print(fTarget, 2);
    Serial.print(" Hz, peak accel ");
    float w = 2.0 * PI * fNow;
    Serial.print(CRANK_MM / 1000.0 * w * w / 9.81, 2);
    Serial.println(" g at the design throw)");
}

void handleLine(String s) {
    s.trim();
    if (s.length() == 0) return;
    if (s == "x" || s == "X") {
        stopTimer();
        Serial.println("STOPPED, driver off.");
        return;
    }
    float f = s.toFloat();
    if (f < 0.0 || (f == 0.0 && s.charAt(0) != '0')) {
        Serial.println("Type a frequency in Hz, 0 to stop, or x.");
        return;
    }
    if (f > fMax) {
        Serial.print("Refused: ");
        Serial.print(f, 2);
        Serial.print(" Hz is above ");
        Serial.print(fMax, 2);
        Serial.println(" Hz for this crank (MAX_G).");
        return;
    }
    if (f > 0.0 && f < F_START) f = F_START;
    fTarget = f;
    reachedReported = false;
    if (f > 0.0 && !running) startTimer(F_START);
    report(f > 0.0 ? "Ramping." : "Ramping down.");
}

// ---- main --------------------------------------------------------------------

void setup() {
    pinMode(PIN_EN, OUTPUT);
    digitalWrite(PIN_EN, HIGH);     // off until asked
    pinMode(PIN_STEP, OUTPUT);
    digitalWrite(PIN_STEP, LOW);
    pinMode(PIN_DIR, OUTPUT);
    digitalWrite(PIN_DIR, HIGH);

    Serial.begin(115200);
    fMax = sqrt(MAX_G * 9.81 / (CRANK_MM / 1000.0)) / (2.0 * PI);

    Serial.println();
    Serial.println("motor_test - shake table, motor only");
    Serial.print("Crank ");
    Serial.print(CRANK_MM, 1);
    Serial.print(" mm, limit ");
    Serial.print(fMax, 2);
    Serial.println(" Hz. Type a frequency, 0 to stop, x for emergency stop.");
}

void loop() {
    static String line;
    while (Serial.available()) {
        char c = Serial.read();
        if (c == '\n' || c == '\r') {
            handleLine(line);
            line = "";
        } else if (line.length() < 20) {
            line += c;
        }
    }

    if (!running) return;
    unsigned long now = millis();
    if (now - lastTick < RAMP_TICK_MS) return;
    lastTick = now;

    // Ramp one small step toward the goal. Compare register values, not
    // floats: the timer can only hit frequencies 16 MHz / integer.
    float goal = (fTarget > 0.0) ? fTarget : F_START;
    uint16_t ocrGoal = ocrFor(goal);
    if (ocrNow != ocrGoal) {
        float stepHz = RAMP_HZ_PER_S * RAMP_TICK_MS / 1000.0;
        float fNext = (fNow < goal) ? min(goal, fNow + stepHz)
                                    : max(goal, fNow - stepHz);
        uint16_t ocrNext = ocrFor(fNext);
        if (ocrNext == ocrNow)              // step too small to change the register
            ocrNext = (ocrGoal < ocrNow) ? ocrNow - 1 : ocrNow + 1;
        fNow = setFreq(freqFor(ocrNext));
        ocrNow = ocrNext;
    } else if (fTarget > 0.0) {
        if (!reachedReported) {
            report("Reached.");
            reachedReported = true;
        }
    } else {
        // down at the start speed and asked to stop
        stopTimer();
        Serial.println("Stopped, driver off.");
    }
}
