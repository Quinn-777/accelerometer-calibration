# accelerometer-calibration

Calibrating an MPU-9250/6500/9255 accelerometer against known references,
in two phases:

**Phase 1 — static.** Six-position calibration using gravity as the
reference. Determines scale factor and zero offset for each axis.

**Phase 2 — dynamic.** A Scotch yoke shake table producing sinusoidal
motion of known amplitude and frequency. Determines frequency response.

## Why

This project came out of [ccs-seismicity-screener](https://github.com/Quinn-777/ccs-seismicity-screener),
a geological screening framework for induced seismicity risk at carbon
storage sites. That framework is validated against monitoring records
from three real projects — and it assumes those records are trustworthy
without ever examining how they were produced.

## Status

- [x] Sensor wired and communicating (I2C 0x68)
- [ ] Calibration cube printed
- [ ] Six-position static calibration
- [ ] Shake table built
- [ ] Frequency sweep
