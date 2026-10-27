# Lab notes

Newest first. Raw counts are at the ±4 g range, where the datasheet gives
8192 counts per g.

## 2026-10-23 — Shake table running; first 3 Hz capture; drive problems

**Built and wired.** NEMA 17 on a DRV8825 at 24 V, 1/8 microstepping,
current limit 1 A (Vref 0.5 V), 100 µF across the motor supply. The step
pulses come from Timer1 in hardware, so the shaft speed is set by the crystal
and does not depend on the sketch keeping time.

**Y axis recalibrated on the carriage.** Five static captures with the base on
end, both directions: 8209 counts/g, offset +95 counts, agreeing to ±2.5
counts after correcting each for its tilt (1.4–3.9°). The magnitude of the
gravity vector was 8310 counts in all three position-1 files; only its split
between the axes changed. Phase 1 gave 8217 for Y.

**First 3 Hz capture**, 13 mm crank (`13mm_3hz_01`). Fundamental on Y
0.4546 g, steady to ±0.8% over six cycles; frequency fitted from the data
2.9990 Hz against 2.9994 Hz commanded. Against the throw measured that evening
(13.60 ± 0.18 mm, carriage pushed outward at each end) that is 0.923 of the
prediction. A later measurement gave 13.07 ± 0.10 mm, one reading per gap,
which makes it 0.960. The acceleration itself implies a throw of 12.55 mm.

The two throw measurements disagree. Pushing the carriage outward adds the
play in the drive to the stroke (2A + c); if friction dominates while running,
the carriage lags by the play at each reversal (2A − c). With 13.60 and 12.55
that would mean about 1 mm of play. Not yet measured. Next: hold the crank at
the end of its stroke, where pushing the carriage cannot turn it, and measure
the play directly; then re-measure the throw three times per gap.

**Things that went wrong, in order.**

- The first 5 Hz capture froze the Mega. A shaken sensor wire made an I2C read
  hang forever, and the motor kept running because its steps come from the
  timer, not the sketch. Fixed with an I2C timeout; failed reads are now
  counted (`i2c_err`) instead of hanging.
- Readings of −1 and −16385 appeared at 5 Hz: bit errors on about 30 cm of
  jumper wire being shaken, with the bus at 400 kHz. Dropped to 100 kHz, which
  still fits a read inside each 2 ms sample at 500 Hz. 1000 Hz sampling is no
  longer offered.
- The sketch reported "Reached 5.0000 Hz" while nothing moved: it only knows
  what it commanded. `capture.py` now fits the drive-frequency amplitude in
  every capture and warns when it is under 30% of the prediction.
- The Mega's GND was not connected to the breadboard ground rail, so the
  driver had no common reference for STEP, DIR and EN. The motor squealed and
  jittered without turning and the driver ran hot. Connecting it fixed that.
- The crank and carriage had come apart, so the crank turned and the carriage
  did not.
- The motor was held by hand, not bolted to its bracket.

**Seventeen 3 Hz runs after that were unusable.** The amplitude ranged from
834 to 3828 counts between runs (about 3700 when working), up to 46 samples
per run hit the ±4 g limit, I2C errors rose to 46 per run, and in one run the
carriage stood still for three cycles and then started. Something in the
drive is slipping and it got worse with each run, so testing stopped there to
avoid wearing the printed parts further. These runs are kept locally, not in
`data/`.

**Before the next capture:** the motor has since been bolted to its bracket.
Still to do: draw a line across the shaft end and the crank and run once, to see whether
the crank slips on the shaft; check that the pin sits in the slot's land;
tape the sensor connectors and fix the wire bundle to the base.

## 2026-10-08 — The 44 Hz claim was wrong; noise and bandwidth measured

**The sensor is an MPU-6500.** WHO_AM_I reads 0x70. The register map gives
0x70 as MPU-6500 and 0x71 as MPU-9250, so the earlier identification from the
board's appearance was a guess that happened to be too generous: there is no
magnetometer on this part. README corrected.

**The stated 44 Hz bandwidth was wrong.** It came from the firmware writing
0x03 to register 0x1A. On the MPU-6050 that sets the bandwidth of both the
gyroscope and the accelerometer; on this part it sets the gyroscope's only.
The accelerometer's filter is in ACCEL_CONFIG2 (0x1D), which no sketch had
ever written. Its reset value is 0x00, the widest setting, so that is what
Phase 1 ran at. None of the Phase 1 results change — a low-pass filter passes
DC unchanged, and six-position calibration measures nothing but DC.

**First attempt to confirm this failed, and the failure is worth recording.**
`burst_log` was written to read 0x1D before overwriting it. But uploading a
sketch resets the board, and the IDE reconnecting the serial monitor resets it
again, so setup() had already run once and written its own value by the time
the printout appeared. The measurement measured itself. The reported value is
only meaningful on the first run after a power cycle, and the firmware now
says so in its own output.

**Measured it instead.** Sensor left still, 1 kHz sampling, all five filter
settings captured back to back without touching anything:

| Setting | Attenuation at 200–240 Hz | Lag-1 autocorrelation |
|---|---|---|
| 20 Hz | −16.4 dB | 0.97 |
| 41 Hz | −15.0 dB | 0.92 |
| 92 Hz | −9.0 dB | 0.86 |
| 184 Hz | none measurable | 0.54 |
| 460 Hz | −3.4 dB | 0.50–0.85 |

Two calculations with nothing in common — one from the spectrum, one from the
raw time series — order the five settings identically, with no exceptions. The
register controls the accelerometer's bandwidth.

**Noise floor.** About 1.0–1.15 counts/√Hz on X and Y in the 20–60 Hz band,
roughly twice that on Z. The Z excess is not the desk: cross-axis correlations
are all below 0.15, and real motion would correlate the axes.

**Ambient.** Below 20 Hz the records are dominated by the building, peaking
near 17 counts/√Hz around 5 Hz — over ten times the sensor's floor, and inside
the 3–12 Hz band the shake table will use. Still about 200× below the planned
drive signal, but background records must be taken in the same session as
loaded ones.

**Three dead ends, recorded so they are not repeated.**

- Comparing the standard deviation of consecutive-sample differences across
  bandwidths does not work. That estimator assumes consecutive samples are
  independent; a filter well below Nyquist makes them correlated and the
  estimator reads low, and reads lower the narrower the filter — precisely the
  comparison it was being used for. It suggested the noise stopped rising above
  184 Hz, which was an artifact.
- At 500 Hz sampling nothing above 250 Hz is observable, so the 460 Hz setting
  cannot be distinguished from 184 Hz at that rate. Both looked identical for
  this reason alone.
- The shallow roll-off was suspected to be spectral leakage from the Hann
  window. Repeating the analysis with a Blackman-Harris window changed nothing,
  so it is not leakage. The cause remains unknown.

**Still open.** The measured corners sit above their nominal frequencies and
the roll-off is gradual. Not explained. It does not affect the conclusion,
which rests on the ordering rather than on the absolute corner positions.

## 2026-09-20 — Six-position calibration and independent check

**Z axis, first pair.** With the cube's +Z face up (chip down), the 12 Sept
reading repeated: ax −607, ay +32, az −8065. Chip up: ax +248, ay +52,
az +8063. Z scale 8059 counts/g (1.6% below datasheet), offset +4 counts.
ax held about −170 counts in both orientations (an offset) plus ±418 counts
that reversed with the flip (a tilt of about 3°).

**Re-tightened the screws and repeated.** Z scale 8054 counts/g, within 0.06%
of the first pair; offset +9. The tilt stayed at 3.1°, so it is fixed
geometry, not uneven tightening.

**All six positions** (six serial lines each):

| Axis | Offset (counts) | Offset (g) | Scale (counts/g) | vs datasheet |
|---|---|---|---|---|
| X | −192 | −0.023 | 8182 | −0.12% |
| Y | +57 | +0.007 | 8217 | +0.31% |
| Z | +9 | +0.001 | 8054 | −1.69% |

Random error about ±7 counts per value.

**Axis mapping.** Cube −Y up puts sensor X at +1 g, cube −X up puts sensor Y
at +1 g, cube −Z up puts sensor Z at +1 g. Sensor X runs along the board's
short edge and Y along the long edge, which matches the silkscreen arrows.

**Mounting angles.** Each rotation shows up in two different position pairs:

- about the line through the two mounting holes: 3.10° and 3.32°
- in the board plane: 1.07° and 1.12°
- about the remaining axis: 0.33° and 0.48°

Both mounting holes sit on the edge away from the pin header, so the header
edge is unsupported. It sits about 0.6 mm high, probably lifted by the jumper
wires. Offsets are unaffected, because the tilt cancels between opposite
faces. The X and Z scale factors come out 0.15–0.19% low; a fit that forces
|a| = 1 g at every position removes this.

An earlier explanation, the board leaning along its long edge by one nut
thickness, assumed sensor X ran along the long edge. The axis mapping showed
it does not.

**Repeatability.** Offsets estimated from different position pairs differ by
20–40 counts (X: −192, −167, −150). The same spread appears when a position
is measured again after picking the cube up, so remounting repeatability, not
the arithmetic, limits accuracy.

**Out-of-sample check.** Three Z readings taken before re-tightening (one from
12 Sept, two from earlier today) were not used in the fit. With the datasheet
scale their magnitude is 1.3–1.6% low; with the new calibration it is
1.001–1.004 g.

**Arbitrary orientations.** A cube balanced on one corner was rejected: its
readings wandered by 130–320 counts against normal noise of about 20, so it
was moving. Seven stable tilts, none used in the fit:

- datasheet scale: spread 1.39%, worst 2.3% from 1 g
- calibrated: spread 0.18%, worst 0.48%, mean 1.0024 g

One of the seven lies only 3° from a calibration position, so it is a weak
test. The calibrated values sit about 0.2% high, as the scale-factor bias
above predicts; with the |a| = 1 g fit the mean is 1.0013 g.

Lesson: when the orientation changes between lines, average the magnitudes,
not the vectors. Averaging vectors that point in different directions gives a
shorter vector.

## 2026-09-12 — Calibration cube printed; first mounted reading

Cube measured with calipers: 49.68 mm between every pair of opposite faces
(design 50.00 mm). No difference between axes. Linear shrinkage 0.64%,
consistent with the roughly 0.3 mm hole undersize seen on 9 Sept.

Sensor mounted chip-side down in the well, on M2 nuts as spacers, with
M2 × 10 screws. Cube +Z face up (chip down), six lines:
ax −569 (sd 23), ay +31 (sd 12), az −8044 (sd 32). Magnitude 8064 counts,
1.6% below nominal. az is negative because the chip faces down.

ax reads −0.069 g. That is either an offset or a tilt of about 4°. Flipping
the cube will separate the two: an offset keeps its sign, a tilt reverses it.

## 2026-09-09 — Fit test, fasteners, and a rejected foam mount

First fit-test print: the pocket was about 1 mm short along the long edge.
board_x changed from 25.0 to 26.0 mm.

Printed holes come out small: holes meant for M3 would not take an M3 screw,
only M2. Estimated shrinkage on holes: about 0.3 mm. Switched to M2 × 10
screws with M2 nuts.

The chip side of the board carries components, so it cannot sit directly on
the well floor. First tried a foam pad under it. Board resting chip-down on
the foam, 36 lines: ax +25 (sd 21), ay +112 (sd 19), az −8149 (sd 30).
Magnitude 8150 counts, 0.5% below nominal, far better than the bare-board
reading on 6 Sept, so most of that earlier error came from the board not
lying flat.

Not used as calibration data. Foam is elastic, so the board's attitude depends
on how it happens to compress, and in a vibration test it would add its own
stiffness and damping. Replaced by M2 nuts as rigid 1.6 mm spacers, which also
keep the components clear of the floor.

Noise on all three axes: about 20–30 counts sd (roughly 0.003 g).

## 2026-09-07 — Board identified; first models

Installed OpenSCAD and modelled a fit test: a 45 × 40 × 6 mm plate with the
sensor pocket and mounting holes. It prints in about 28 minutes, against 4 or
more hours for the full cube, so pocket and hole sizes can be checked cheaply.

The first model assumed a GY-521 (MPU-6050) board. Comparing it with the real
board showed an MPU-9250/6500/9255 breakout (GY-9250 style), about
25 × 15 mm, with both mounting holes along one long edge. The registers used,
the I2C address (0x68) and the ±4 g scale are the same, so the firmware and
the 6 Sept readings still hold. Model revised.

## 2026-09-06 — First contact with the sensor

Wired the sensor to an Arduino Mega 2560: VCC→5V, GND→GND, SCL→21, SDA→20.
The I2C scan found the device at 0x68 on the first try.

The first serial output was garbage: the monitor was at 9600 baud and the
sketch at 115200. Garbage output usually means a baud mismatch, not broken
code.

read_raw working. Bare board flat on the desk, chip up: ax −300, ay +40,
az +7990. Inverted: az −8120. Vector magnitude 7996 counts, 2.4% below
nominal. Z two-position estimate: offset −65 counts, scale 8055 counts/g.
