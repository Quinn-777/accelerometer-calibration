// carriage.scad
// The moving part of the Scotch-yoke shake table: it rides on the two 5 mm
// guide rods and carries the sensor. The yoke slot itself is a SEPARATE part
// (yoke_plate.scad) bolted to the -y face, for two reasons: its slot width
// has to match the finished pin diameter, and it is the only surface that
// wears. Reprinting a 40-minute plate beats reprinting this.
//
// Coordinates, same as motor_mount.scad:
//   x  travel
//   y  along the motor shaft
//   z  up from the base board
// Rod axes and the crank axis all sit at z = shaft_z. That alignment is not
// cosmetic - see rod_block.scad for what it buys.
//
// PRINT: slice it exactly as it lands, flat on the bed, no supports and no
// rotating. With print_ready = true the body is already dropped to z = 0.
// The rod bores come out as teardrops (see rod_bore) so their roofs do not
// sag. There is no sensor cover any more - see "sensor pocket" below.
print_ready = true;

$fn = 64;

// ---------------------------------------------------------------------------
// How much a printed hole shrinks: what is actually known
//
// Every caliper reading taken inside a hole on this project is suspect. The
// jaws have to sit on a true diameter; anywhere else they measure a chord,
// which reads short. The 2026-10-10 readings on rod_fit_test show this
// directly - rocking the caliper in one bore gave anything from 4.55 to
// 5.30. So those numbers bound the diameter from BELOW and nothing more, and
// an earlier draft of this file was wrong to treat 0.50 mm as measured.
//
// The one trustworthy data point is not a measurement at all, it is a gauge:
// hole S is modelled 5.30, 5 mm deep, and a 5.00 mm rod enters it while
// scraping plastic. That puts hole S at roughly 4.95-5.00, so a shallow
// vertical bore loses about 0.30-0.35 mm - close to the original figure from
// the calibration cube, not the 0.50 claimed in between.
//
// Every hole below is therefore sized to be acceptable across the whole
// 0.30-0.50 range rather than tuned to one value.
hole_comp = 0.35;

// ---------------------------------------------------------------------------
// Why the rod bores are four short lands and not two long bushings
//
// rod_fit_test was printed with 12 mm deep bores modelled 5.35, 5.45 and
// 5.55, and the 5 mm rod would not enter any of them - while hole S, 5 mm
// deep and modelled 0.05 mm TIGHTER than the smallest of the three, does
// take it. Depth is what fails. The caliper cannot see where, because its
// jaws only reach a few millimetres in, which is exactly why the mouth of
// those bores measures close to the modelled size.
//
// So each rod runs in two 4 mm lands instead, one at each end of the body,
// with the bore between them opened up so it cannot touch. Three things
// improve at once:
//   - each land is shorter than hole S, which is known to come out at a
//     predictable size;
//   - the two lands for one rod lie at different x in the SAME layers, so
//     their alignment is set by XY positioning, about 0.05 mm, instead of by
//     how straight the printer stacks 12 mm of layers;
//   - the clearance can be tight, because a short land cannot bind.
// ---------------------------------------------------------------------------

rod_d    = 5.0;

// <-- SET THIS from land_fit_test: the MODELLED diameter of whichever land
//     the rod slid through most snugly. Lands 1 to 7 on the coupon are
//     5.05 / 5.15 / 5.25 / 5.35 / 5.45 / 5.55 / 5.65.
//     It is written as a finished number on purpose. No compensation figure
//     for a short horizontal bore is worth trusting on this printer - the
//     caliper readings on the deep bores contradict each other by 0.8 mm -
//     so the coupon, with the rod as the gauge, IS the measurement.
// land_fit_test, 2026-10-13: land 3 (5.25) would not take the rod, land 4
// (5.35) let it drop through under its own weight with slight drag - near
// zero clearance - and land 5 (5.45) slid freely. Four lands at zero
// clearance bind, so the carriage uses land 5, one step above the fit.
land_bore_d = 5.45;

land_w   = 4.0;        // bearing length of one land
relief   = 1.0;        // extra diameter between the lands

shaft_z     = 26.0;    // MUST match motor_mount.scad and rod_block.scad
rod_spacing = 30.0;    // MUST match rod_block.scad

// ---------------------------------------------------------------------------
// Body length, and why it is not longer
//
// The rods are 100 mm. With 10 mm gripped in each end block the free span is
// 80 mm, and the carriage plus its full stroke has to fit inside it:
//     46 (body) + 26 (peak-to-peak at A = 13 mm) = 72 mm, leaving 4 mm at
// each end. A longer body would resist rocking better but would run out of
// rod before reaching A = 13 mm.
//
// What the 42 mm land spacing buys: at 0.10 mm clearance the body can pitch
// by atan(0.10 / 42) = 0.14 deg. Pitch is the rotation that matters, because
// it tips the travel axis out of horizontal and lets gravity leak into the
// reading: g * sin(0.14 deg) = 0.0024 g, about 20 counts. Against the
// smallest signal in the programme, 0.47 g at 3 Hz with A = 13 mm, that is
// 0.5%; against the largest, 4 g, it is 0.06%.
//
// It is also separable, which matters more than its size. The leak is fixed
// by clearance and geometry, so it is roughly CONSTANT with frequency, while
// the real signal grows as f^2. Fitting
//     measured amplitude = S * A * (2*pi*f)^2 + E
// across several frequencies at one crank throw returns the constant E as its
// own term instead of letting it bias the scale factor S.
//
// Yaw does not matter the same way: rotating about the vertical axis leaves
// the travel axis horizontal, so no gravity leaks in. That is why the yoke
// plate is allowed to hang off one side rather than sit on the centreline.
// ---------------------------------------------------------------------------

body_len = 46.0;
body_y0  = -6.0;                       // face the yoke plate bolts to
body_y1  = rod_spacing + 6.0;
body_z0  = 17.0;
body_z1  = 35.0;

// --- sensor pocket   (REDESIGNED 2026-10-16) ----------------------------
// Board outline 26 x 16 mm, as corrected on the 2026-09-09 fit test.
//
// The board is held the way it was in the Phase 1 cube: chip-side down,
// two M2 screws through its own mounting holes, here into two tapped
// standoffs. The pin header and the Dupont plugs on it stand straight up
// with nothing over them. The earlier version laid the board on two rails
// and clamped it with a flat cover, which could not close over the plugs.
//
// ORIENTATION: mounting-hole edge toward -y (the yoke-plate face, toward the
// motor), header edge toward +y. Hole positions are the ones the Phase 1
// fit test confirmed on this board: 10.5 mm either side of the board centre
// along its length, 4.5 mm from the centre toward the hole edge.
//
// The header edge is not supported, as in the cube, and does not need to be.
// Both screws sit on one line along x, the travel direction, so the most the
// board can do is turn slightly about that line. The sensor's Y axis runs
// along the board's long edge, i.e. along x, the measurement axis, and a
// rotation about x leaves it pointing exactly where it was. The 3.2 deg tilt
// measured in the cube was a rotation about this same line.
//
// The header's solder stubs hang into the 5.2 mm of clear space under the
// board, and nothing in the pocket is under them now.
//
// The board ends up about 9 mm above the rod axes. That offset decides
// WHICH harmonic the rocking lands on, not how big it is - the body pitches
// to its clearance stop either way - so it is left where the part is simple
// to print and to assemble.
board_x   = 26.0;
board_y   = 16.0;
board_t   = 1.6;
board_gap = 0.5;       // slip fit around the board outline. A pocket this
                       // size loses far less than a small bore does, but
                       // 0.4 was cutting it fine at the newly measured rate.
under_h   = 5.2;       // clear space under the board for the header pins
hole_dx   = 10.5;      // board mounting holes, from the board centre
hole_dy   = 4.5;       // toward the -y (hole) edge
standoff_d = 4.6;      // sits on the plain ring around each hole
tap_depth = 8.0;       // M2 x 8 screw: 1.6 board + 6.4 into the standoff
proud     = 1.0;       // how far the board stands above the body top

pocket_x  = board_x + 2 * board_gap;
pocket_y  = board_y + 2 * board_gap;
rail_top  = body_z1 + proud - board_t;   // underside of the board
floor_z   = rail_top - under_h;

pocket_cx = body_len / 2;
pocket_cy = rod_spacing / 2;

// --- fasteners ---------------------------------------------------------
// Written as finished modelled numbers, not as "want + hole_comp", because
// the compensation is only known to about +/-0.1 mm and these have to work
// across all of it:
//   m2_clear 2.75 -> about 2.40 actual, clearance for an M2
//   m2_tap   2.25 -> measured, see below
m2_clear = 2.75;
// land_fit_test, 2026-10-13: of bosses A-G (modelled 1.65 to 2.55 in 0.15
// steps), an M2 screw cut the best thread in E, modelled 2.25. That is the
// size used for every self-tapped M2 hole in this project.
m2_tap   = 2.25;
plate_screw_dx = 9.0;           // yoke plate screws, either side of centre
plate_screw_dz = 5.9;           // and above/below the rod bore, which they
                                // have to clear - see the asserts below
seat_depth = 1.0;               // shallow seat locating the yoke plate

land_r   = land_bore_d / 2;
relief_r = (land_bore_d + relief) / 2;

// The yoke plate screws run into the -y face, through the thin band of
// material left above and below the relieved bore. Both margins are checked
// here rather than left to be discovered in the slicer.
assert(plate_screw_dz - m2_tap / 2 - relief_r > 1.2,
       "yoke plate screws are too close to the rod bore");
assert(body_z1 - (shaft_z + plate_screw_dz + m2_tap / 2) > 1.2,
       "yoke plate screws are too close to the top face");
assert(shaft_z - plate_screw_dz - m2_tap / 2 - body_z0 > 1.2,
       "yoke plate screws are too close to the bottom face");
// The sensor pocket must stay clear of both rod bores in y.
assert(pocket_cy - pocket_y / 2 - relief_r > 1.5 &&
       rod_spacing - relief_r - (pocket_cy + pocket_y / 2) > 1.5,
       "sensor pocket overlaps a rod bore");

// Teardrop profile: a circle with a 45 deg roof, so a horizontal bore has no
// flat ceiling to sag. The diamond is 2% oversize so it overlaps the circle
// properly instead of meeting it tangentially, which CGAL dislikes.
module teardrop_profile(d) {
    r = d / 2;
    circle(r = r);
    rotate(45) square([r * 1.02, r * 1.02]);
}

// Bore along +x of the given length, teardrop apex pointing +z.
module rod_bore(d, len) {
    rotate([0, 90, 0]) rotate([0, 0, 90])
        linear_extrude(height = len)
            teardrop_profile(d);
}

// The relieved section starts exactly at land_w and the land bores run 0.5 mm
// past it, so the small-diameter region is land_w long to the millimetre and
// the two cuts still overlap rather than meeting on a shared face.
module rod_channel() {
    translate([-1, 0, 0]) rod_bore(land_bore_d, land_w + 1.5);
    translate([body_len - land_w - 0.5, 0, 0])
        rod_bore(land_bore_d, land_w + 1.5);
    translate([land_w, 0, 0])
        rod_bore(land_bore_d + relief, body_len - 2 * land_w);
}

module body() {
    difference() {
        translate([0, body_y0, body_z0])
            cube([body_len, body_y1 - body_y0, body_z1 - body_z0]);

        for (y = [0, rod_spacing])
            translate([0, y, shaft_z]) rod_channel();

        // seat and screws for the yoke plate, in the -y face
        translate([pocket_cx - 12, body_y0 - 1, body_z0 - 1])
            cube([24, seat_depth + 1, body_z1 - body_z0 + 2]);
        for (dx = [-1, 1], dz = [-1, 1])
            translate([pocket_cx + dx * plate_screw_dx,
                       body_y0 - 1,
                       shaft_z + dz * plate_screw_dz])
                rotate([-90, 0, 0]) cylinder(d = m2_tap, h = 9);

        // sensor pocket, with the two standoffs left standing
        difference() {
            translate([pocket_cx - pocket_x / 2, pocket_cy - pocket_y / 2, floor_z])
                cube([pocket_x, pocket_y, body_z1 - floor_z + 1]);
            for (dx = [-1, 1])
                translate([pocket_cx + dx * hole_dx, pocket_cy - hole_dy, floor_z - 1])
                    cylinder(d = standoff_d, h = under_h + 1);
        }

        // M2 tapped holes down the standoffs, for the board's own screws
        for (dx = [-1, 1])
            translate([pocket_cx + dx * hole_dx, pocket_cy - hole_dy,
                       rail_top - tap_depth])
                cylinder(d = m2_tap, h = tap_depth + 2);
    }
}

// Standoffs and tapped holes, checked here rather than in the slicer.
assert(pocket_cx - hole_dx - standoff_d / 2 > pocket_cx - pocket_x / 2 + 0.4,
       "standoff runs into the end wall of the pocket");
assert(rail_top - tap_depth > body_z0 + 3,
       "tapped hole runs too close to the carriage underside");
assert(pocket_cy - hole_dy - relief_r > 6,
       "tapped hole runs too close to a rod bore");

translate([0, 0, print_ready ? -body_z0 : 0]) body();
