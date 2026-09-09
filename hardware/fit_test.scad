// fit_test.scad
// Fit test for an MPU-9250/6500/9255 breakout (GY-9250 style board).
// Both mounting holes sit along one edge, near the two ends.

// ===== MEASURE THESE ON YOUR OWN BOARD =====
board_x   = 26.0;    // long edge
board_y   = 15.0;    // short edge
hole_dx   = 10.5;    // hole centre, distance from board centre along X
hole_dy   = 4.5;     // hole centre, distance from board centre along Y
                     // negative side; both holes share this offset
// ===========================================

fit       = 0.6;     // clearance around the board, per side
hole_dia  = 3;     // M3 self-taps into PLA
plate_x   = 45;
plate_y   = 40;
plate_z   = 6;
pocket_z  = 3;

$fn = 48;

difference() {
    cube([plate_x, plate_y, plate_z], center = true);

    // pocket matching the board outline
    translate([0, 0, plate_z/2 - pocket_z/2 + 0.01])
        cube([board_x + 2*fit, board_y + 2*fit, pocket_z], center = true);

    // two holes along the same edge
    for (s = [-1, 1])
        translate([s * hole_dx, -hole_dy, 0])
            cylinder(h = plate_z * 2, d = hole_dia, center = true);
}
