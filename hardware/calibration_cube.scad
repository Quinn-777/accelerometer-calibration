// calibration_cube.scad
// Six-position calibration cube for an MPU-9250/6500/9255 breakout.
// Each face is engraved with the cube axis its outward normal points along.

// ===== COPY THESE FROM YOUR VERIFIED fit_test.scad =====
board_x   = 26.0;    // long edge of the PCB
board_y   = 15.0;    // short edge
hole_dx   = 10.5;    // hole centre, distance from board centre along X
hole_dy   = 4.5;     // hole centre, distance from board centre along Y
fit       = 0.6;     // clearance around the board, per side
hole_dia  = 3.0;     // M3 self-taps into PLA
// =======================================================

cube_size    = 50;
well_depth   = 30;   // swallows the pin header plus dupont housings
hole_depth   = 8;
channel_w    = 12;   // wire exit slot
channel_h    = 8;

label_size   = 11;   // engraved text height
label_depth  = 1.0;  // engraving depth

$fn = 48;

module face_label(txt) {
    linear_extrude(height = label_depth * 2, center = true)
        text(txt, size = label_size, halign = "center", valign = "center",
             font = "Liberation Sans:style=Bold");
}

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

    // ---- engraved face labels ----
    // +Z sits off-centre to clear the well and the wire channel
    translate([0, -16, cube_size/2])                face_label("+Z");
    translate([0, 0, -cube_size/2]) rotate([180,0,0])   face_label("-Z");
    translate([cube_size/2, 0, 0])  rotate([90,0,90])   face_label("+X");
    translate([-cube_size/2, 0, 0]) rotate([90,0,-90])  face_label("-X");
    translate([0, cube_size/2, 0])  rotate([90,0,180])  face_label("+Y");
    translate([0, -cube_size/2, 0]) rotate([90,0,0])    face_label("-Y");
}