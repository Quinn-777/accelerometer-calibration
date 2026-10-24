// base.scad
// Printed base plate for the Phase 2 shake table. Replaces the wooden board:
// the motor mount and both rod blocks sit in shallow pockets, which put them
// in the right place relative to each other, and are held by M3 screws
// threaded straight into the plastic. No wood screws, no measuring.
//
// Coordinates are motor_mount.scad's (the "machine" frame):
//   x  travel; the motor shaft is at x = 0
//   y  along the motor shaft; the motor-mount face is at y = 0, the motor
//      body hangs toward -y, the rods are at y = 41 and 71
//   z  up; z = 0 is the TOP of this base, the surface everything stands on
// carriage.scad / rod_block.scad use the carriage frame, which is this one
// shifted by x - 23, y + 41 (assembly.scad, CAR_Y = 41).
//
// ---------------------------------------------------------------------------
// The screw holes, from the measured error
//
// Nothing here has been fit-tested with an M3 screw, so the size comes from
// the M2 result scaled up:
//   - land_fit_test, boss E: an M2 cut its best thread in a hole modelled
//     2.25. Shallow holes on this printer come out 0.30-0.35 mm small, so
//     that hole was really about 1.92 mm: the screw cut only the outer 17%
//     of its thread depth ((2.00 - 1.92) / (2.00 - 1.57)).
//   - The same 17% on an M3 (major 3.00, minor 2.46) is a hole of
//     3.00 - 0.17 x 0.54 = 2.91 mm, modelled 2.91 + 0.32 = 3.23.
//   - Rounded to 3.20, a hair tighter: an M3 is stronger than an M2, and a
//     tighter hole holds better in a plate that is never taken apart often.
// Only the first 8 mm under each pocket is the tapped size; below that the
// hole opens to clearance. Deep printed holes close up on this printer, and
// an M3 x 10 through the 6 mm motor-mount wing only reaches 4 mm in anyway.
// That first 8 mm is also printed first, right at the bed, where holes come
// out truest - the base prints upside down (see PRINT).
//
// The pockets: printed pocket vs printed part, 0.4 mm clearance a side as
// modelled. A pocket loses about 0.15 a side and a printed outside edge
// gains about 0.1, so each part goes in with roughly 0.15 a side to spare.
// That is the most any part can shift: 0.15 mm, against several mm of
// clearance everywhere in the moving assembly.
//
// Everything that was measured "from the base board" is measured from the
// POCKET FLOOR now: all three parts drop 1 mm together, so the motor shaft
// and the rods are still at the same height as each other. The motor body
// hangs over the plain top surface with 3.85 mm of air under it.
// ---------------------------------------------------------------------------
//
// SCREWS: 8 x M3. Through the motor-mount wings (6 mm): M3 x 10 to M3 x 16.
// Through the rod-block floors (4 mm): M3 x 8 to M3 x 14. Turn each one in
// slowly the first time - it is cutting its own thread.
//
// PRINT: upside down, top face on the bed (print_ready = true already does
// this). The surface the parts stand on is then the flattest surface the
// printer can make, the ribs point up with no overhang, and no support is
// needed. Same settings as every other part. Takes several hours.
//
// USE: put it on a solid table. Rubber feet or a heavy book on each end stop
// it walking at 12 Hz.

print_ready = true;

$fn = 64;

// --- from the other files ----------------------------------------------------
CAR_Y = 41;             // carriage frame y = 0 sits at machine y = 41
CAR_X = -23;            // carriage frame x = 23 sits at machine x = 0

// motor_mount.scad: plate_w 52, foot reaches y = 28, wings 14 x 22
mm_half_w   = 26.0;
mm_back_y   = 28.0;
mm_wing_out = 40.0;     // 26 + 14
mm_wing_y   = 22.0;
mm_screws   = [for (sx = [-1, 1], y = [5.0, 17.0]) [sx * 33.0, y]];

// rod_block.scad, carriage frame: body x -33..-17, y -12..42,
// ledge x -17..-3, y 4..26, board screws at x -25, y 9 and 21.
// The right block is the same part turned about (23, 15).
blk_body   = [[-33, -17], [-12, 42]];
blk_ledge  = [[-17,  -3], [  4, 26]];
blk_screws = [[-25, 9], [-25, 21]];

// motor body (only to check it clears the base): 42.3 square, centre z 26,
// from y = 0 back to y = -38, bottom 26 - 21.15 = 4.85 above its floor
motor_back_y = -38.0;

// --- this part -----------------------------------------------------------------
pocket_d   = 1.0;       // pocket depth
pocket_c   = 0.4;       // clearance per side, as modelled
pocket_ch  = 0.5;       // 45 deg chamfer round each pocket mouth (it is on
                        // the bed when printing: stops elephant's foot)
plate_t    = 4.0;       // solid plate under the top surface
rib_h      = 12.0;      // total height, plate + ribs
rib_t      = 3.0;
boss_d     = 9.0;
m3_tap     = 3.20;      // see "The screw holes"
tap_len    = 8.0;
m3_clear   = 3.60;

x_min = -62; x_max = 62;
y_min = -42; y_max = 87;

// ---- rod-block footprint in machine coordinates --------------------------------
function car2m(p) = [p[0] + CAR_X, p[1] + CAR_Y];
function rot_c(p) = [46 - p[0], 30 - p[1]];          // the right-hand block

// Every pocket is a union of rectangles [[x0, x1], [y0, y1]], machine frame.
function blk_rect(r, right) =
    let(a = right ? rot_c([r[0][1], r[1][1]]) : [r[0][0], r[1][0]],
        b = right ? rot_c([r[0][0], r[1][0]]) : [r[0][1], r[1][1]],
        ma = car2m(a), mb = car2m(b))
    [[ma[0], mb[0]], [ma[1], mb[1]]];

pocket_rects = [
    [[-mm_half_w, mm_half_w], [0, mm_back_y]],          // motor-mount plate + foot
    [[-mm_wing_out, mm_wing_out], [0, mm_wing_y]],      // motor-mount wings
    blk_rect(blk_body, false), blk_rect(blk_ledge, false),
    blk_rect(blk_body, true),  blk_rect(blk_ledge, true)];

module rect(r, grow = 0)
    translate([r[0][0] - grow, r[1][0] - grow])
        square([r[0][1] - r[0][0] + 2 * grow, r[1][1] - r[1][0] + 2 * grow]);

function all_screws() = concat(
    mm_screws,
    [for (s = blk_screws) car2m(s)],
    [for (s = blk_screws) car2m(rot_c(s))]);

// ---- checks ----------------------------------------------------------------------
assert(car2m([-33, 0])[0] - pocket_c - pocket_ch > x_min + 3, "left block off the plate");
assert(car2m(rot_c([-33, 0]))[0] + pocket_c + pocket_ch < x_max - 3, "right block off the plate");
assert(car2m([0, 42])[1] + pocket_c + pocket_ch < y_max - 3, "blocks off the back of the plate");
assert(motor_back_y > y_min + 2, "motor overhangs the front of the plate");
// The rod-block pockets and the motor-mount pocket never meet: the blocks
// sit at |x| >= 26 + ... beyond the foot, and their ledges (|x| 26..40) are
// at y >= 45, far behind the wings (y <= 22).
assert(car2m([-3, 4])[0] <= -mm_half_w + 0.01 && car2m([-3, 4])[1] > mm_wing_y + 2 * pocket_c,
       "rod-block ledge pocket runs into the motor-mount pocket");
assert(pocket_d + tap_len <= rib_h - 1, "tapped length longer than the boss");
assert(x_max - x_min <= 220 && y_max - y_min <= 220, "bigger than the bed");

echo(str("base ", x_max - x_min, " x ", y_max - y_min, " x ", rib_h, " mm; screws at ",
         all_screws()));

// ---- the base, top face at z = 0 ------------------------------------------------------
rib_x = [x_min + rib_t / 2, -48, -33, 0, 33, 48, x_max - rib_t / 2];   // ribs along y
rib_y = [y_min + rib_t / 2, 11, 56, y_max - rib_t / 2];                // ribs along x

module base() {
    difference() {
        union() {
            translate([x_min, y_min, -plate_t]) cube([x_max - x_min, y_max - y_min, plate_t]);
            // ribs and bosses underneath
            for (x = rib_x)
                translate([x - rib_t / 2, y_min, -rib_h]) cube([rib_t, y_max - y_min, rib_h]);
            for (y = rib_y)
                translate([x_min, y - rib_t / 2, -rib_h]) cube([x_max - x_min, rib_t, rib_h]);
            for (s = all_screws())
                translate([s[0], s[1], -rib_h]) cylinder(d = boss_d, h = rib_h);
        }
        // pockets, with a 45 deg chamfer round the mouth
        for (r = pocket_rects) {
            translate([0, 0, -pocket_d]) linear_extrude(pocket_d + 1) rect(r, pocket_c);
            hull() {
                translate([0, 0, -pocket_ch]) linear_extrude(0.01) rect(r, pocket_c);
                translate([0, 0, 0.01]) linear_extrude(0.01) rect(r, pocket_c + pocket_ch + 0.01);
            }
        }
        // screw holes: tapped for the first tap_len below the pocket floor,
        // clearance below that
        for (s = all_screws()) translate([s[0], s[1], 0]) {
            translate([0, 0, -pocket_d - tap_len]) cylinder(d = m3_tap, h = tap_len + 0.01);
            translate([0, 0, -rib_h - 1]) cylinder(d = m3_clear, h = rib_h + 1 - pocket_d - tap_len);
        }
    }
}

if (print_ready)
    // top face down on the bed: rotate 180 deg about x
    rotate([180, 0, 0]) base();
else
    base();
