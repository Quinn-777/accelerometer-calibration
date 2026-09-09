# Lab notes

## 2026-09-06

Wired GY-521 to Mega 2560 (VCC→5V, GND→GND, SCL→21, SDA→20).
I2C scan found the device at 0x68 first try.

Serial output was garbage at first — monitor was at 9600 baud, sketch
uses 115200. Fixed by changing the monitor.

read_raw working. Flat, chip up: ax −300, ay 40, az 7990.
Inverted: az −8120.

Datasheet says 8192 counts per g at ±4g, so the sensor reads about
2% low. That's what the calibration is for.
## 2026-09-09

First fit_test print. Pocket is about 1 mm short along the long edge.
Measured printed pocket: 25 x 16 mm (design 26.2 x 16.2).
Measured board: 26 x 16 mm.
Cause: [board larger than assumed / print shrinkage].
Fix: board_x 25.0 -> 26.0, reprinting.
