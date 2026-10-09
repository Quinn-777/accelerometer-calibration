// crank.scad
// Scotch-yoke crank for the Phase 2 shake table.
//
// The crank throw IS the motion amplitude, so there is one crank per
// amplitude. Set `amplitude` below, render, export, repeat.
//
//   amplitude = 13 mm  ->  3 to 6 Hz    (0.47 g at 3 Hz, 1.88 g at 6 Hz)
//   amplitude =  9 mm  ->  6 to 9 Hz    (1.30 g at 6 Hz, 2.93 g at 9 Hz)
//   amplitude =  6 mm  ->  9 to 12 Hz   (1.96 g at 9 Hz, 3.48 g at 12 Hz)
//
// Peak acceleration is amplitude * (2*pi*f)^2. The three ranges are chosen so
// every measurement point lands between 0.5 and 3.5 g: high enough above the
// noise floor to be worth reporting, and clear of the +/-4 g full scale. They
// deliberately overlap at 6 and 9 Hz, so those two frequencies can each be
// measured at two different amplitudes. If the two agree, the mechanism is
// behaving; if they do not, something is rattling, and that is worth more
// than either number on its own.
//
// Why the pin is printed rather than a screw: a screw's threads would chew
// the slot, and its head is an off-centre steel mass that shakes the frame at
// exactly the drive frequency - the one frequency the measurement cannot tell
// apart from the real motion. A printed PLA pin weighs about 0.16 g, which
// makes that error about 0.3% of the drive force instead of 2%.
//
// Fit on the shaft is an interference fit with no fastener. Bore modelled at
// 5.30 mm, which prints at about 5.00 mm and presses onto the shaft. That
// holds far more than the 4 Ncm this mechanism needs. If it turns out loose,
// say so and a clamping version follows - do not force a cracked one on.

amplitude = 6;        // <-- the only value to change: 13, then 9, then 6

$fn = 96;

// Same bore compensation as the calibration cube: printed holes come out
// about 0.30 mm under the modelled size on this printer.
hole_comp = 0.30;

shaft_d = 5.0;         // NEMA 17 shaft
disc_t  = 14.0;        // grip length on the shaft
pin_d   = 4.0;         // must match the slot chosen on yoke_fit_test
pin_h   = 10.0;
wall    = 3.0;         // material outboard of the pin

disc_d  = 2 * (amplitude + pin_d / 2 + wall);

label_depth = 0.6;
label_x     = -(disc_d / 4 + 2);

module pin() {
    cylinder(d1 = pin_d + 2, d2 = pin_d, h = 1.0);          // base flare
    translate([0, 0, 1.0]) cylinder(d = pin_d, h = pin_h - 2.0);
    translate([0, 0, pin_h - 1.0])
        cylinder(d1 = pin_d, d2 = pin_d - 1.2, h = 1.0);    // tip chamfer
}

// Printed with this face down: the pin points up and nothing overhangs, so
// the part needs no support. In use it is flipped, pin towards the yoke.
difference() {
    union() {
        cylinder(d = disc_d, h = disc_t);
        translate([amplitude, 0, disc_t]) pin();
    }

    translate([0, 0, -0.5])
        cylinder(d = shaft_d + hole_comp, h = disc_t + 1);

    translate([label_x, 0, disc_t - label_depth])
        linear_extrude(height = label_depth + 0.1)
            text(str(amplitude), size = 5, halign = "center", valign = "center");
}
