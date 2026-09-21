# Lab notes

Newest first. Raw counts are at the ±4 g range, where the datasheet gives
8192 counts per g.

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
