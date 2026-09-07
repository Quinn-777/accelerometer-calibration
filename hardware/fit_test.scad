// fit_test.scad
// Print this first. 20 minutes instead of 4 hours.
// Verifies the pocket size and hole spacing before committing to the cube.

board_x      = 21.5;   // adjust after measuring your own board
board_y      = 16.5;
hole_spacing = 15.5;

fit       = 0.5;       // clearance around the board
hole_dia  = 2.8;       // M3 self-tapping into PLA
plate_x   = 45;
plate_y   = 40;
plate_z   = 6;
pocket_z  = 3;

$fn = 48;

difference() {
    cube([plate_x, plate_y, plate_z], center = true);

    // pocket, identical to the well in the full cube
    translate([0, 0, plate_z/2 - pocket_z/2 + 0.01])
        cube([board_x + 2*fit, board_y + 2*fit, pocket_z], center = true);

    // the two mounting holes
    for (s = [-1, 1])
        translate([s * hole_spacing/2, 0, 0])
            cylinder(h = plate_z * 2, d = hole_dia, center = true);
}