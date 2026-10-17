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
//
// Load check, 2026-10-13, for a 38 mm NEMA 17 taken as 0.35 kg (heavier than
// a typical 0.25-0.30 kg, to be safe). The motor hangs off the front of the
// plate with its centre of mass 19 mm in front of the face:
//   - bending at the plate root from the weight:  3.4 N x 22 mm = 0.075 N*m
//     -> 0.24 MPa, about 1/100 of what PLA layers hold;
//   - the four M3 motor screws share 3.4 N of shear - nothing;
//   - tipping forward about the plate's front edge is held by the two rear
//     board screws (y = 17): 3.4 N x 19 / 17 = 3.8 N between them;
//   - the peak crank reaction (5.1 N along x at shaft height, 6 mm crank at
//     12 Hz) rocks it sideways: 5.1 N x 26 / 66 = 2.0 N per side.
// A wood screw holds well over 100 N in pull-out. Strength is not the limit;
// stiffness is, and that is why the base is a wooden board.
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

// Height of the shaft axis above the base board. MUST match rod_block.scad
// and carriage.scad.
//
// The motor body hangs off the FRONT of the plate (y < 0), over the bare
// board; the foot reaches BACK (y > 0), under the crank. So the motor only
// has to clear the board, not the foot: 26 - 42.3 / 2 = 4.85 mm of air under
// a standard 42.3 mm body. Body length (38 mm on the motor bought) does not
// enter anything here.
//
// ASSEMBLY: turn the motor so its cable connector points UP or sideways,
// never down - the connector housing stands about 6 mm proud of the body
// and would hit the board through that 4.85 mm gap.
shaft_z = 26.0;

plate_t  = 6.0;        // the plate the motor bolts to
plate_w  = 52.0;       // across, in the travel direction
plate_h  = 52.0;       // upright
foot_t   = 6.0;
foot_d   = 22.0;       // how far the foot reaches back - see "keep-out"
gusset_t = 5.0;

bolt_clear_d = 3.4;    // M3 clearance

// ---------------------------------------------------------------------------
// Fixing to the base board (CHANGED 2026-10-13)
//
// The board screws used to go through the foot at x = +/-19, between the two
// gussets. A screw head 7 mm across there overlaps the 5 mm gusset by 1.5 mm
// and cannot seat, and a screwdriver shank hits the gusset on the way down.
// All four holes are now in two WINGS that stick out sideways beyond the
// gussets, where nothing stands above them - not the plate, not the motor
// (|x| <= 21.15), not the crank (|x| <= 18.25). They can be driven at any
// stage of assembly.
//
// Two holes per side, 12 mm apart front-to-back, so the bracket is held
// against tipping forward under the motor's weight (see the load note at the
// top of the file).
wing_w  = 14.0;        // how far each wing sticks out past the plate side
wing_d  = 22.0;        // front-to-back, starting at the plate face (y = 0)
board_screw_d = 4.20;  // -> about 3.85 actual: #6 / 3.5 mm wood screw or M3
board_screw_x = plate_w / 2 + wing_w / 2;           // 33 mm from the axis
board_screw_y = [5.0, 17.0];

// ---------------------------------------------------------------------------
// Keep-out: the rod blocks
//
// With the carriage centred on the crank axis, the rod blocks' 40 mm flanges
// start 25 mm either side of the axis, so the bracket must stay clear of
// them in y. The foot now stops at y = plate_t + foot_d = 28 and the wings at
// y = 22. The yoke plate design must put the rod-block flanges behind y = 30.
bracket_back_y = plate_t + foot_d;

// Every cut runs along +y, from 1 mm in front of the plate face (y = -1) to
// 1 mm behind its back face (y = plate_t + 1). rotate([-90, 0, 0]) is the
// rotation that sends +z to +y.
//
// FIXED 2026-10-13: this used rotate([90, 0, 0]), which sends +z to -y, so
// all five holes ran out of the FRONT of the plate and only cut its first
// 1 mm. A part printed from the earlier file has blind holes and cannot be
// used.
module nema_face_cutouts() {
    // central bore: clears the 22 mm boss and the shaft
    translate([0, -1, 0])
        rotate([-90, 0, 0])
            cylinder(d = nema_boss_d + 2.0 + hole_comp, h = plate_t + 2);

    // four mounting holes
    for (dx = [-1, 1], dz = [-1, 1])
        translate([dx * nema_bolt_pitch / 2, -1, dz * nema_bolt_pitch / 2])
            rotate([-90, 0, 0])
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

// Vertical board-screw hole with a small pointed roof toward +y. In the print
// orientation +y is UP, so the hole prints horizontal and the roof keeps its
// top from sagging.
module board_hole() {
    r = board_screw_d / 2;
    translate([0, 0, -1])
        linear_extrude(height = foot_t + 2) {
            circle(r = r);
            translate([0, r * 0.3]) rotate(45) square(r * 1.1, center = true);
        }
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

        // two wings for the board screws, flush with the plate face
        for (dx = [-1, 1])
            translate([dx > 0 ? plate_w / 2 - 0.01 : -plate_w / 2 - wing_w + 0.01,
                       0, 0])
                cube([wing_w, wing_d, foot_t]);

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

    // four holes to screw the bracket down to the base board, in the wings
    for (dx = [-1, 1], y = board_screw_y)
        translate([dx * board_screw_x, y, 0]) board_hole();
}
