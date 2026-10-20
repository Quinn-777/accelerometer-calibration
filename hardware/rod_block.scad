// rod_block.scad
// End blocks for the two 5 mm guide rods, plus the tie bar that joins them.
// Print TWO blocks and ONE bar. Both ends use the same block STL: turned
// round 180 deg, the left block is the right block.
//
// Coordinates match carriage.scad (the carriage frame):
//   x  travel; the carriage is 46 mm long and centred at x = 23
//   y  along the motor shaft; the rods are at y = 0 and y = 30
//   z  up from the base board; the rod axes are at z = 26
//
// ---------------------------------------------------------------------------
// CHANGED 2026-10-20: blind bores and a tie bar instead of a V and a cap
//
// The V-and-cap blocks did not hold the rods. The cap only gripped each rod
// by a modelled 0.2 mm, so any shrinkage left it loose, and nothing at all
// stopped a rod sliding out along its own length.
//
// Now each rod sits in a BLIND bore: open on the side facing the carriage,
// closed on the outside. The rods are pushed into one block, the carriage is
// slid on, the second block is pushed onto the other ends, and the tie bar
// is screwed across underneath. With both ends closed and the two blocks tied
// together, a rod has nowhere to go.
//
// Why the bores are good enough now when the old 12 mm deep bores were not:
//   - the block prints standing on its OUTER face, so each bore is a vertical
//     hole, printed in the X-Y plane where this printer is accurate;
//   - it grips the rod only on two 4 mm lands with a relief between them, the
//     same construction as the carriage (5.45, sliding) and the crank hub
//     (5.40, fits the 5 mm shaft). 5.40 is used here, for a snug hold;
//   - an M2 set screw from the top presses on each rod, in case 5.40 turns
//     out loose.
// The bore centres are X-Y positions in the print, so the rod spacing (30)
// and rod height (26) come out as modelled - better than the V, which moved
// the rods up and down with shrinkage.
//
// ASSEMBLY ORDER
//   1. Push both rods into block A until they hit the closed ends.
//   2. Slide the carriage onto the rods.
//   3. Push block B onto the other ends, until the rods bottom out.
//   4. Lay the tie bar across the two ledges and screw it down: 4 x M2x8.
//      Its holes are slots, so it fits whatever the real rod length is.
//   5. Tighten the four M2 set screws on top just until the rods stop moving.
//      Do not crank them: the rod only needs to stop moving.
//   6. Screw both blocks to the base board, 2 screws each.
// ---------------------------------------------------------------------------

part = "all";          // "block", "bar", or "all" (two blocks + bar, for a look)
print_ready = true;    // block: outer face on the bed; bar: flat

$fn = 64;

// --- shared with carriage.scad / motor_mount.scad --------------------------
rod_d       = 5.0;
rod_len     = 100.0;   // the rods bought; slots in the bar take +/- 1.5
shaft_z     = 26.0;    // MUST match motor_mount.scad and carriage.scad
rod_spacing = 30.0;    // MUST match carriage.scad
car_x0      = 0;       // carriage body x 0..46, centred at x = 23
car_len     = 46.0;
car_z0      = 17.0;    // carriage underside
max_throw   = 13.0;    // largest crank

// --- tested sizes on this printer -------------------------------------------
land_d   = 5.40;       // crank shaft_test #3: a 5 mm shaft goes in snug
land_w   = 4.0;
relief_d = 6.2;
entry_ch = 0.6;        // lead-in on the open end of each bore
m2_tap   = 2.25;       // land_fit_test boss E
m2_clear = 2.75;
m2_head_cb = 4.6;      // counterbore for an M2 head (3.8 mm)
board_screw_d = 4.20;  // wood screw #6 / 3.5 mm, or M3
board_cb_d    = 7.5;   // counterbore for the wood-screw head

// --- block -----------------------------------------------------------------
rod_end_x  = (car_len / 2) - rod_len / 2;   // -27: left rod end
grip       = 10.0;                          // rod length inside each block
end_wall   = 6.0;                           // the closed outer end
x_in       = rod_end_x + grip;              // -17: face toward the carriage
x_out      = rod_end_x - end_wall;          // -33: outer face (on the bed)
blk_y0     = -12.0;
blk_y1     = rod_spacing + 12.0;
blk_top    = 34.0;

// board screws: between the rods, through the block's full height
board_y    = [9.0, rod_spacing - 9.0];
board_x    = (x_in + x_out) / 2;
board_cb_floor = 8.0;  // screw head sits 8 mm above the board: a 20-25 mm
                       // wood screw then has 12-17 mm in the wood

// set screws: from the top, onto the rod, over the entry land
set_x      = x_in - land_w / 2;

// ledge for the tie bar, sticking out of the inner face at board level
ledge_l    = 12.0;     // how far it reaches toward the carriage
ledge_y0   = 4.0;
ledge_y1   = rod_spacing - 4.0;
ledge_t    = 8.0;      // z 0..8
ledge_screw_y = [9.5, rod_spacing - 9.5];
ledge_screw_x = x_in + ledge_l / 2;

// --- tie bar ---------------------------------------------------------------
bar_t      = 5.0;      // z 8..13
bar_cb_h   = 2.0;      // head counterbore depth -> 3 mm under the head,
                       // so an M2x8 has 5 mm of thread in the ledge
bar_slot   = 1.5;      // each hole is a slot +/- this along x
bar_x0     = x_in + 1.0;                     // left end
bar_x1     = (car_len - x_in) - 1.0;         // right end, by symmetry
bar_y0     = ledge_y0 + 1.0;
bar_y1     = ledge_y1 - 1.0;

// ---- checks ---------------------------------------------------------------
assert(abs(rod_end_x - (-27)) < 0.01, "rods should run x = -27 .. 73");
assert(x_in <= car_x0 - max_throw - 4 + 0.01,
       "less than 4 mm from the carriage at full stroke");
assert(ledge_t + bar_t <= car_z0 - 4,
       "tie bar comes within 4 mm of the carriage underside");
assert(blk_top - (shaft_z + relief_d / 2) >= 4.5,
       "not enough plastic above the rod for the set screw");
assert(abs(board_y[0] - 0) - board_cb_d / 2 - relief_d / 2 >= 1.5,
       "board-screw counterbore too close to the rod bore");
assert(board_x - board_cb_d / 2 - x_out >= 2 && x_in - board_x - board_cb_d / 2 >= 2,
       "board-screw counterbore too close to the block faces");
assert(min(ledge_screw_y) - ledge_y0 >= 3, "ledge screw too near the edge");
assert(2 * land_w <= grip, "lands longer than the grip");

// ---- helpers ----------------------------------------------------------------
// A hole along machine z with a pointed roof toward +x. In the print
// orientation +x is UP, so these holes print horizontal and the point
// keeps their tops from sagging.
module tear_z(d, z0, h) {
    translate([0, 0, z0]) linear_extrude(h) {
        circle(d = d);
        rotate(-45) square(d / 2);
    }
}

// One blind bore, axis along +x, from the closed end at rod_end_x to the
// inner face.
module bore(y) {
    translate([rod_end_x, y, shaft_z]) rotate([0, 90, 0]) {
        // bottom land (deep end) and entry land, through the whole grip
        cylinder(d = land_d, h = grip + 1);
        // relief between the lands, with a 45 deg step back down to the
        // entry land so nothing overhangs in the print
        r_len = grip - 2 * land_w;
        if (r_len > 0) {
            translate([0, 0, land_w]) cylinder(d = relief_d, h = r_len);
            translate([0, 0, land_w + r_len])
                cylinder(d1 = relief_d, d2 = land_d, h = (relief_d - land_d) / 2);
        }
        // lead-in at the open end
        translate([0, 0, grip - entry_ch + 0.01])
            cylinder(d1 = land_d, d2 = land_d + 2 * entry_ch, h = entry_ch);
    }
}

module block() {
    difference() {
        union() {
            translate([x_out, blk_y0, 0])
                cube([x_in - x_out, blk_y1 - blk_y0, blk_top]);
            translate([x_in - 0.01, ledge_y0, 0])
                cube([ledge_l + 0.01, ledge_y1 - ledge_y0, ledge_t]);
        }
        for (y = [0, rod_spacing]) bore(y);

        // set screws onto the rods
        for (y = [0, rod_spacing])
            translate([set_x, y, shaft_z]) tear_z(m2_tap, 0, blk_top);

        // board screws: clearance all the way, head counterbore from the top
        for (y = board_y) translate([board_x, y, 0]) {
            tear_z(board_screw_d, -1, blk_top + 2);
            tear_z(board_cb_d, board_cb_floor, blk_top);
        }

        // tie-bar screws into the ledge
        for (y = ledge_screw_y)
            translate([ledge_screw_x, y, 0]) tear_z(m2_tap, 1.0, ledge_t);
    }
}

// The right-hand block: the same part turned 180 deg about the vertical
// line through the middle of the rods.
module block_right()
    translate([car_len / 2, rod_spacing / 2, 0]) rotate([0, 0, 180])
        translate([-car_len / 2, -rod_spacing / 2, 0]) block();

module slot_hole(d, len, h) {
    hull() for (dx = [-len, len]) translate([dx, 0, 0]) cylinder(d = d, h = h);
}

module bar() {
    difference() {
        translate([bar_x0, bar_y0, ledge_t]) cube([bar_x1 - bar_x0, bar_y1 - bar_y0, bar_t]);
        for (x = [ledge_screw_x, car_len - ledge_screw_x], y = ledge_screw_y)
            translate([x, y, ledge_t - 1]) {
                slot_hole(m2_clear, bar_slot, bar_t + 2);
                translate([0, 0, 1 + bar_t - bar_cb_h])
                    slot_hole(m2_head_cb, bar_slot, bar_cb_h + 1);
            }
    }
}

echo(str("block x ", x_out, "..", x_in, ", ledge to ", x_in + ledge_l,
         "; bar x ", bar_x0, "..", bar_x1, " (", bar_x1 - bar_x0, " mm)"));

// ---- output -----------------------------------------------------------------
if (part == "block") {
    if (print_ready)
        // outer face (x = x_out) down; +x (toward the carriage) becomes up
        translate([0, 0, -x_out]) rotate([0, -90, 0]) block();
    else block();
}
if (part == "bar") {
    if (print_ready) translate([0, 0, -ledge_t]) bar();
    else bar();
}
if (part == "all") { block(); block_right(); bar(); }
