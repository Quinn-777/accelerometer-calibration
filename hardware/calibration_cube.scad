// calibration_cube.scad
// Six-position calibration cube for an MPU-9250/6500/9255 breakout.
// The sensor bolts into a deep well on the +Z face so that no face
// is obstructed when the cube is rolled onto it.

// ===== COPY THESE FROM YOUR VERIFIED fit_test.scad =====
board_x   = 25.0;    // long edge of the PCB
board_y   = 15.0;    // short edge
hole_dx   = 10.5;    // hole centre, distance from board centre along X
hole_dy   = 4.5;     // hole centre, distance from board centre along Y
fit       = 0.6;     // clearance around the board, per side
hole_dia  = 2.8;     // M3 self-taps into PLA
// =======================================================

cube_size    = 50;
well_depth   = 30;   // swallows the pin header plus dupont housings
hole_depth   = 8;
channel_w    = 12;   // wire exit slot
channel_h    = 8;

$fn = 48;

difference() {
    cube([cube_size, cube_size, cube_size], center = true);

    // sensor well, opening on the +Z face
    translate([0, 0, cube_size/2 - well_depth/2 + 0.01])
        cube([board_x + 2*fit, board_y + 2*fit, well_depth], center = true);

    // two blind self-tapping holes in the well floor
    for (s = [-1, 1])
        translate([s * hole_dx, -hole_dy,
                   cube_size/2 - well_depth - hole_depth/2 + 0.01])
            cylinder(h = hole_depth, d = hole_dia, center = true);

    // wire exit channel through the +Y wall, open at the top edge
    translate([0, cube_size/4, cube_size/2 - channel_h/2 + 0.01])
        cube([channel_w, cube_size/2 + 0.02, channel_h], center = true);
}