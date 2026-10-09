// yoke_fit_test.scad
// Coupon to size the Scotch-yoke slot before committing to the real parts.
// Prints in about 40 minutes, against several hours for a frame.
//
// It prints as TWO objects: the plate, and a loose test pin that matches the
// pin on the crank. The point is to measure a printed pin against a printed
// slot, because that is the actual sliding pair in the mechanism. Nothing
// here needs any purchased hardware.
//
// What to do with it:
//   1. Measure the test pin's diameter with the calipers and write it down.
//      Modelled at 4.00 mm. External features usually print slightly OVER
//      size, unlike holes, so expect something like 4.05-4.20 mm.
//   2. Try the pin in slots 1, 2 and 3. Pick the tightest one in which the
//      pin still slides from end to end under its own weight with no
//      detectable side-to-side rock.
//   3. Hole S takes the 5 mm motor shaft (test it when the motor arrives, or
//      with any 5 mm rod or drill shank).
//      Hole T is M3 tapping size: an M3 screw should cut its own thread and
//      need a screwdriver to turn.
//      Hole C is M3 clearance: an M3 screw should drop straight through.
//
// Report the pin diameter and which slot won. Both numbers go straight into
// the carriage, and the slot clearance is what sets how much backlash the
// mechanism has - which is the thing most likely to put a ceiling on the
// usable frequency range.

$fn = 64;

// Printed bores come out about 0.30 mm under the modelled size on this
// printer, measured on the calibration cube (M3 holes would only take M2).
// Every slot and hole below adds it back.
hole_comp = 0.30;

plate_x = 72;
plate_y = 44;
plate_z = 5;

pin_d = 4.0;                    // printed pin, same as crank.scad
pin_h = 10.0;

fits = [0.15, 0.30, 0.45];      // side clearances to compare

slot_len = 16;
slot_y   = 26;
slot_x   = [16, 36, 56];

hole_y  = 9;
shaft_d = 5.0;
tap_d   = 2.5;
clear_d = 3.4;

label_depth = 0.8;

module engrave(s, x, y, size) {
    translate([x, y, plate_z - label_depth])
        linear_extrude(height = label_depth + 0.1)
            text(s, size = size, halign = "center", valign = "center");
}

module slot(w, len, h) {
    hull() {
        translate([0, -len / 2, 0]) cylinder(d = w, h = h);
        translate([0,  len / 2, 0]) cylinder(d = w, h = h);
    }
}

// The pin, with a flare at the base for strength and a chamfer at the tip so
// it feeds into the slot. Identical to the pin on the crank.
module test_pin() {
    cylinder(d1 = pin_d + 2, d2 = pin_d, h = 1.0);
    translate([0, 0, 1.0])  cylinder(d = pin_d, h = pin_h - 2.0);
    translate([0, 0, pin_h - 1.0])
        cylinder(d1 = pin_d, d2 = pin_d - 1.2, h = 1.0);
}

// ---- object 1: the plate ----
difference() {
    cube([plate_x, plate_y, plate_z]);

    for (i = [0 : 2]) {
        translate([slot_x[i], slot_y, -0.5])
            slot(pin_d + fits[i] + hole_comp, slot_len, plate_z + 1);
    }

    translate([16, hole_y, -0.5])
        cylinder(d = shaft_d + hole_comp, h = plate_z + 1);
    translate([36, hole_y, -0.5])
        cylinder(d = tap_d + hole_comp, h = plate_z + 1);
    translate([56, hole_y, -0.5])
        cylinder(d = clear_d + hole_comp, h = plate_z + 1);

    engrave("1", 16, 40, 5);
    engrave("2", 36, 40, 5);
    engrave("3", 56, 40, 5);
    engrave("S", 16, 2.8, 4);
    engrave("T", 36, 2.8, 4);
    engrave("C", 56, 2.8, 4);
}

// ---- object 2: the loose test pin, on its own small base ----
translate([plate_x + 8, 8, 0]) {
    cube([14, 14, 2], center = false);
    translate([7, 7, 2]) test_pin();
}
