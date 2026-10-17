// yoke_slot_test.scad
// Fifteen minutes of printing to choose slot_w in yoke_plate.scad.
//
// Eight short slots, numbered 1 to 8, modelled 4.30 to 5.00 mm wide in
// 0.10 mm steps. The coupon is the same 10 mm thickness as the yoke plate and
// prints the same way up - lead-in side on the bed, slot walls vertical - so
// a slot here comes out the same width as the same slot there.
//
// The widths are fixed numbers, not "pin + something", so this can be
// printed before the pin is sanded. Across 4.30-5.00 it covers a sanded pin
// anywhere from about 3.9 to 4.6 mm at the 0.30-0.35 mm loss measured on hole
// S, with clearance from zero up to about 0.2 mm.
//
// HOW TO USE IT
//   1. Sand the crank pin round first (see crank.scad).
//   2. Push the pin into each slot from the chamfered side and slide it from
//      one end of the slot to the other.
//   3. Pick the NARROWEST slot it slides along freely, without sticking.
//      Do not go a size up (see "why tight" in yoke_plate.scad).
//   4. Put that slot's width into slot_w in yoke_plate.scad:
//        1: 4.30   2: 4.40   3: 4.50   4: 4.60
//        5: 4.70   6: 4.80   7: 4.90   8: 5.00
//   If the pin will not go into 8, or rattles in 1, the answer is outside the
//   range - say so before printing the plate.
//
// PRINT: slice it exactly as it lands, no supports, same settings as the
// other parts.

widths   = [4.30, 4.40, 4.50, 4.60, 4.70, 4.80, 4.90, 5.00];
plate_t  = 10.0;       // = yoke_plate.scad plate_t
slot_len = 13.0;       // long enough to slide the pin through 8 mm of travel
pitch    = 9.0;
edge     = 4.0;
lead_in  = 1.2;        // same 45 deg entry chamfer as the yoke plate
label_d  = 0.6;

$fn = 64;

n = len(widths);
coupon_x = 2 * edge + (n - 1) * pitch + widths[n - 1];
coupon_y = slot_len + 2 * 5 + 4;      // room for the numbers above the slots

module slot2d(w) {
    hull() for (y = [w / 2, slot_len - w / 2])
        translate([0, y]) circle(d = w);
}

difference() {
    cube([coupon_x, coupon_y, plate_t]);
    for (i = [0 : n - 1]) {
        w = widths[i];
        cx = edge + widths[n - 1] / 2 + i * pitch;
        translate([cx, 5, 0]) {
            // the slot, through the full thickness
            translate([0, 0, -1]) linear_extrude(plate_t + 2) slot2d(w);
            // lead-in on the bed side
            hull() {
                translate([0, 0, -0.01]) linear_extrude(0.01)
                    offset(r = lead_in) slot2d(w);
                translate([0, 0, lead_in]) linear_extrude(0.01) slot2d(w);
            }
        }
        // number on the top face
        translate([cx, 5 + slot_len + 3, plate_t - label_d])
            linear_extrude(label_d + 0.1)
                text(str(i + 1), size = 3.2, halign = "center", valign = "center");
    }
}
