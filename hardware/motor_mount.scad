// motor_mount.scad
// L-bracket holding the NEMA 17 on its side, shaft horizontal, for the
// Phase 2 Scotch-yoke shake table.
//
// Layout: the motor lies on its side so the crank turns in a vertical plane
// and the yoke slot is vertical. The drive force is then in the plane of the
// slot plate rather than across it, which is the stiff direction. Gravity
// acts along the slot, so the carriage's weight is carried by the rods and
// the pin only ever sees the drive force.
//
// Screw the foot flat to a wooden base board. Wood is far stiffer than any
// printed frame, and the first resonance of the assembly is the number this
// whole experiment is trying to push upward.
//
// PRINT ORIENTATION: motor face down on the bed. With print_ready = true
// below, the part is already rotated that way on export, so just slice it as
// it lands - no rotating in the slicer.
//
// Why this way and not on its side: the two gussets only exist at the left
// and right edges, so laying the part on a side face makes the second gusset
// appear in mid-air partway through the print, with nothing under it. Face
// down, every layer is narrower than the one below it, so there is no
// overhang anywhere and no support is needed. It also puts the four motor
// bolt holes and the 24 mm boss bore along the build direction, where they
// come out round, instead of across it, where their tops sag.
//
// The plate-to-foot joint does land on a layer plane this way, which is the
// weak direction. It does not matter here: motor weight and crank reaction
// together put about 0.19 N*m into a 52 x 6 mm section, which is 0.6 MPa
// against roughly 30 MPa of layer adhesion.
print_ready = true;
//
// Dimensions that are standard and therefore safe to hard-code: NEMA 17 has
// a 31.0 mm square bolt pattern, a 22 mm centring boss and a 42.3 mm body.
// What is NOT standard is body length, so nothing here depends on it.

$fn = 64;

hole_comp = 0.30;      // printed bores come out this much under size

// --- NEMA 17, fixed by the standard ---
nema_bolt_pitch = 31.0;
nema_boss_d     = 22.0;
nema_body       = 42.3;

// --- the one dimension to check against your own parts ---
// Height of the shaft axis above the base board. It has to clear half the
// motor body (42.3 / 2 = 21.15 mm) plus the foot, or the motor fouls the
// board. 26 mm leaves about 5 mm of air under the motor.
shaft_z = 26.0;

plate_t  = 6.0;        // the plate the motor bolts to
plate_w  = 52.0;       // across, in the travel direction
plate_h  = 52.0;       // upright
foot_t   = 6.0;
foot_d   = 34.0;       // how far the foot reaches back
gusset_t = 5.0;

bolt_clear_d = 3.4;    // M3 clearance
board_screw_d = 3.8;   // M3 bolt or a #6 wood screw into the board

module nema_face_cutouts() {
    // central bore: clears the 22 mm boss and the shaft
    rotate([90, 0, 0])
        translate([0, 0, -1])
            cylinder(d = nema_boss_d + 2.0 + hole_comp, h = plate_t + 2);

    // four mounting holes
    for (dx = [-1, 1], dz = [-1, 1])
        translate([dx * nema_bolt_pitch / 2, 0, dz * nema_bolt_pitch / 2])
            rotate([90, 0, 0])
                translate([0, 0, -1])
                    cylinder(d = bolt_clear_d + hole_comp, h = plate_t + 2);
}

// Right triangle bracing the plate against the foot. After the rotation the
// polygon's local x becomes global z (up the plate) and local y becomes
// global y (back along the foot), so both must be positive or the gusset
// ends up in front of the plate, where the motor goes.
module gusset() {
    rotate([0, -90, 0])
        linear_extrude(height = gusset_t)
            polygon([[0, 0], [0, foot_d - 4], [plate_h - 8, 0]]);
}

// Modelled upright, as it sits in the machine; rotated flat only on export.
rotate(print_ready ? [90, 0, 0] : [0, 0, 0])
difference() {
    union() {
        // upright plate, its face at y = 0, shaft axis at z = shaft_z
        translate([-plate_w / 2, 0, shaft_z - plate_h / 2])
            cube([plate_w, plate_t, plate_h]);

        // foot, reaching back from the plate
        translate([-plate_w / 2, plate_t, 0])
            cube([plate_w, foot_d, foot_t]);

        // one gusset at each side face. The extrusion always runs towards
        // -x, so the left one is shifted in by its own thickness to keep
        // both of them inside the plate's width.
        for (dx = [-1, 1])
            translate([dx * plate_w / 2 + (dx < 0 ? gusset_t : 0),
                       plate_t, foot_t])
                gusset();
    }

    // motor face: boss bore and four bolt holes
    translate([0, 0, shaft_z]) nema_face_cutouts();

    // four holes to screw the foot down to the base board
    for (dx = [-1, 1], dy = [0, 1])
        translate([dx * (plate_w / 2 - 7),
                   plate_t + 8 + dy * (foot_d - 16),
                   -1])
            cylinder(d = board_screw_d + hole_comp, h = foot_t + 2);
}
