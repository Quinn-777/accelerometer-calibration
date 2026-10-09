// rod_fit_test.scad
// Coupon to size a printed plain bushing on the 5 mm stainless rod.
//
// Print this together with yoke_fit_test - it is small and adds about 20
// minutes. Between the two coupons, every sliding fit in the mechanism gets
// measured before anything large is committed to.
//
// What to do with it:
//   1. Push a 5 mm rod through bores A, B and C in turn.
//   2. Pick the tightest bore the rod still slides through smoothly by hand
//      over the full 12 mm, with no side-to-side rock. A trace of grease is
//      allowed and will be used in the real carriage.
//   3. If even C binds, say so - the compensation is off and everything else
//      that depends on hole_comp needs revisiting, including the cube.
//
// The bores are 12 mm deep on purpose: that is a realistic bushing length,
// and a fit that feels fine over 3 mm can bind over 12 mm once any
// misalignment between the two rods is in play.

$fn = 64;

hole_comp = 0.30;      // printed bores come out this much under size
rod_d     = 5.0;

// Final bore sizes aimed at, before compensation: a plain bearing wants a
// little more than the shaft, unlike the press fit used for the motor shaft.
clearances = [0.05, 0.15, 0.25];

plate_x = 54;
plate_y = 24;
plate_z = 12;

bore_x = [13, 27, 41];
bore_y = 14;

label_depth = 0.8;

module engrave(s, x, y, size) {
    translate([x, y, plate_z - label_depth])
        linear_extrude(height = label_depth + 0.1)
            text(s, size = size, halign = "center", valign = "center");
}

difference() {
    cube([plate_x, plate_y, plate_z]);

    for (i = [0 : 2])
        translate([bore_x[i], bore_y, -0.5])
            cylinder(d = rod_d + clearances[i] + hole_comp, h = plate_z + 1);

    engrave("A", bore_x[0], 4.5, 5);
    engrave("B", bore_x[1], 4.5, 5);
    engrave("C", bore_x[2], 4.5, 5);
}
