// land_fit_test.scad
// One print that settles the two numbers the carriage, rod blocks and cranks
// are waiting on:
//   1. what modelled diameter a SHORT HORIZONTAL bore needs for the 5 mm rod
//      (the carria！ge runs on four 4 mm lands printed exactly like these);
//   2. what modelled diameter an M2 screw can cut its own thread in.
// Do NOT print the carriage, rod blocks or cranks before this has been tried.
//
// ---------------------------------------------------------------------------
// What is actually known going in (2026-10-10)
//
// Caliper readings taken inside printed holes are not trustworthy: the same
// bore read anywhere from 4.55 to 5.30 depending on how the jaws sat, because
// anything off a true diameter measures a chord. The one firm data point is a
// gauge result: hole S on yoke_fit_test is modelled 5.30, 5 mm deep, vertical,
// and the 5.00 rod enters it while scraping plastic. So a shallow VERTICAL
// bore loses about 0.30-0.35 mm.
//
// A short HORIZONTAL bore with a teardrop roof has never been tried on this
// printer. This coupon does not measure it; it offers nine sizes and lets the
// rod pick. The rod is a better instrument here than the caliper.
//
// ---------------------------------------------------------------------------
// Changes from the version sent earlier the same day
//
//   - BUG FIX: the rod bores used to be cut the full width of the base, so
//     they also drilled sideways through all three screw bosses (bore 4 went
//     straight through the middle of one, across its tapped hole). The
//     bores are now cut through the walls only, and the bosses sit midway
//     between rod stations, clear of a rod pushed through any land.
//   - Two more lands, 5.75 and 5.85. The old top size, 5.65, only covered a
//     loss up to about 0.6 mm; if the horizontal bores lose more than that,
//     the old coupon would have had no land that fits and cost a reprint.
//   - Walls 18 mm tall instead of 16, so the bore has 9 mm of material above
//     and below it, the same as on the carriage.
//   - Labels moved to the top of the base, where they print cleanly, instead
//     of on the 4 mm wide wall face.
//   - Seven screw bosses instead of three (X/Y/Z are gone), 0.15 mm apart
//     instead of 0.20, from a size that is too small at any plausible
//     shrinkage to one that is too big at any plausible shrinkage. Three
//     sizes could miss on either side and say nothing.
//
// ---------------------------------------------------------------------------
// HOW TO USE IT
//
// RODS - lands 1 to 9, modelled 5.05 to 5.85 in 0.10 steps.
//   1. Deburr the rod end first, or it will drag on every land.
//   2. Stand the coupon on its side so the bores are VERTICAL, and drop the
//      rod into each land from above. Do not push.
//   3. Find the SMALLEST land the rod falls through by its own weight without
//      scraping. Call it L. (Scraping or needing a push = too small.)
//   4. Report L. The carriage does NOT use L itself: L is close to zero
//      clearance, and four lands at zero clearance bind partway through the
//      stroke. The carriage uses one step larger, L + 0.10, which is the
//      0.10-0.15 mm sliding clearance the design calls for.
//   5. If even land 9 is tight, or land 1 is already loose, say so: the
//      answer is outside the range.
//
// SCREWS - bosses A to G, 8.5 mm deep:
//     A 1.65   B 1.80   C 1.95   D 2.10   E 2.25   F 2.40   G 2.55
//   A should split or refuse the screw and G should let it spin; if not,
//   the answer is outside the range - say so.
//   Drive an M2 x 10 screw into each. The right one is the LARGEST hole that
//   still needs a screwdriver to turn and holds firmly when you pull on the
//   screw. Spins freely = too big. Splits the boss = too small.
//   (No M2 screws yet? Skip this half and report the rods only.)
//
// PRINT: slice it exactly as it lands - flat, no supports, no rotating.
// PLA, 0.2 mm layers, 3 walls, 20% infill. About an hour.
// ---------------------------------------------------------------------------

$fn = 64;

// Modelled bore diameters, written as finished numbers rather than as
// rod + clearance + compensation. Compensation is the thing under test, so
// building it into the formula would assume the answer.
//   no shrinkage at all          -> land 1 or 2
//   about 0.35, like hole S      -> land 4 or 5
//   up to about 0.8              -> land 8 or 9
bores = [5.05, 5.15, 5.25, 5.35, 5.45, 5.55, 5.65, 5.75, 5.85];

// Modelled tapped-hole diameters. An M2 screw (major 2.00, minor about
// 1.57) self-taps well into about 1.6-1.8 mm of PLA. For a hole loss
// anywhere from 0.15 to 0.60 mm, A comes out too small and G too big, with
// the right size somewhere between. The parts currently use 2.10 (= D).
taps       = [1.65, 1.80, 1.95, 2.10, 2.25, 2.40, 2.55];
tap_labels = ["A", "B", "C", "D", "E", "F", "G"];

land_w  = 4.0;         // wall thickness = bearing length, as on the carriage
axis_z  = 9.0;         // bore centre above the bed
wall_h  = 18.0;        // 9 mm of material above and below the bore centre
pitch_y = 16.0;        // spacing between rod stations
wall_x  = 13.0;        // centre of the walls in x
base_x  = 40.0;
base_t  = 4.0;

boss_x    = 30.0;
boss_d    = 9.0;
boss_h    = 8.0;       // above the base top
tap_depth = 8.5;

label_depth = 0.6;

n = len(bores);
station_y = [for (i = [0 : n - 1]) i * pitch_y + pitch_y / 2];

// Bosses sit on the boundaries between rod stations (multiples of pitch_y),
// so each is a full pitch_y / 2 = 8 mm from the nearest rod line.
boss_y = [for (i = [0 : len(taps) - 1]) (i + 1) * pitch_y];

// ---- checks -----------------------------------------------------------
// A rod pushed all the way through any land must pass every boss.
for (b = boss_y, s = station_y)
    assert(abs(b - s) >= boss_d / 2 + 2.5 + 0.5,
           str("boss at y=", b, " is in the path of the rod at y=", s));
// Bosses stay on the base.
assert(boss_y[len(boss_y) - 1] + boss_d / 2 < n * pitch_y,
       "a boss hangs off the end of the base");
// The largest teardrop must stay inside its wall, with 1.5 mm to spare at the
// top. Its apex is at r * 1.02 * sqrt(2) above the centre.
assert(axis_z + bores[n - 1] / 2 * 1.02 * sqrt(2) + 1.5 < wall_h,
       "the largest bore breaks through the top of its wall");
// And its bottom must clear the base top, so the rod never touches the base.
assert(axis_z - bores[n - 1] / 2 > base_t + 1.0,
       "the largest bore cuts into the base");
// The tapped holes must leave a floor under them.
assert(base_t + boss_h - tap_depth >= 3.0, "tapped holes leave too thin a floor");

// ---- geometry ---------------------------------------------------------
// Teardrop: a circle with a 45 deg roof, so a horizontal bore has no flat
// ceiling to sag. Identical to the profile in carriage.scad.
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

module top_label(s, x, y, size) {
    translate([x, y, base_t - label_depth])
        linear_extrude(height = label_depth + 0.1)
            text(s, size = size, halign = "center", valign = "center");
}

difference() {
    union() {
        cube([base_x, n * pitch_y, base_t]);
        for (i = [0 : n - 1])
            translate([wall_x - land_w / 2, i * pitch_y + 2, 0])
                cube([land_w, pitch_y - 4, wall_h]);
        for (y = boss_y)
            translate([boss_x, y, 0])
                cylinder(d = boss_d, h = base_t + boss_h);
    }

    // Rod bores, cut through the walls ONLY (1 mm overrun each side).
    for (i = [0 : n - 1]) {
        translate([wall_x - land_w / 2 - 1, station_y[i], axis_z])
            rod_bore(bores[i], land_w + 2);
        top_label(str(i + 1), 5.0, station_y[i], 5);
    }

    // Tapped holes, from the top of each boss down.
    for (i = [0 : len(taps) - 1]) {
        translate([boss_x, boss_y[i], base_t + boss_h - tap_depth])
            cylinder(d = taps[i], h = tap_depth + 0.1);
        top_label(tap_labels[i], 20.5, boss_y[i], 4.5);
    }
}
