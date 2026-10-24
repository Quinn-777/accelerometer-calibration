// yoke_slot_test.scad
// About half an hour of printing to choose slot_w in yoke_plate.scad.
//
// Eighteen short slots in two rows, numbered 1 to 18, modelled 4.50 to
// 6.20 mm wide in 0.10 mm steps. Each is built exactly like the slot in yoke_plate.scad and
// printed the same way up:
//   - a 1.2 mm 45 deg lead-in on the bed side (stops elephant's foot closing
//     the mouth),
//   - a 4 mm LAND at the slot width,
//   - and behind it the slot opened up by 1 mm, so the land is the only part
//     that touches the pin.
// So a slot here comes out the same width as the same slot on the plate.
//
// CHANGED 2026-10-20. The first coupon cut each slot straight through 10 mm
// of plastic, and the pin would not go into any of them, 5.00 included. A
// 10 mm deep slot is a 10 mm deep printed hole, and deep printed holes on
// this printer wander and close up - the same thing rod_fit_test showed,
// and the reason the carriage and the crank hub already use short lands.
// Measured on that coupon: slot 8 (modelled 5.00) was 4.27 across, and the
// plate's 4.60 slot was 4.1 - 0.5 to 0.7 mm lost. So the range is now
// twice as wide: at the low end it still fits a pin sanded to about 4.2
// if the land works as well as on the carriage (0.3 mm lost); at the high
// end it fits an unsanded 4.8 mm pin even if the land fixes nothing and
// 1.4 mm is lost.
//
// The widths differ by only 0.10 mm, so the slots will LOOK identical. That
// is expected. Calipers across the straight middle of a slot are fine
// (it is round holes where they read a chord), but the pin is the gauge.
//
// HOW TO USE IT
//   1. Caliper the crank pin three times at mid-height, about 60 deg apart.
//      If the readings differ by more than 0.05 mm, sand it round first
//      (see crank.scad) - sanding afterwards would change which slot fits.
//   2. Turn the coupon over and push the pin into each slot from the
//      chamfered (bed) side, the way it enters the real plate, then slide it
//      from one end of the slot to the other. The numbers are on the other
//      face, so note which slot you are at before turning the coupon over.
//   3. Pick the NARROWEST slot it slides along freely, without sticking.
//      Do not go a size up (see "why tight" in yoke_plate.scad).
//   4. Put that slot's width into slot_w in yoke_plate.scad:
//        front row             back row
//         1: 4.50   2: 4.60    10: 5.40  11: 5.50
//         3: 4.70   4: 4.80    12: 5.60  13: 5.70
//         5: 4.90   6: 5.00    14: 5.80  15: 5.90
//         7: 5.10   8: 5.20    16: 6.00  17: 6.10
//         9: 5.30              18: 6.20
//   (slot_w = 4.50 + 0.10 x (number - 1).)
//   If the pin will not go into 18, or rattles in 1, say so before printing
//   the plate.
//
// PRINT: slice it exactly as it lands - chamfered side down, no supports,
// same settings as the other parts.

widths   = [for (i = [0 : 17]) 4.50 + 0.10 * i];   // 4.50 .. 6.20
per_row  = 9;
plate_t  = 10.0;       // = yoke_plate.scad plate_t
slot_len = 13.0;       // long enough to slide the pin through 8 mm of travel
lead_in  = 1.2;        // = yoke_plate.scad entry_cham
land_w   = 4.0;        // = yoke_plate.scad land_w
relief   = 1.0;        // = yoke_plate.scad relief
pitch    = 10.0;
edge     = 4.0;
label_d  = 0.6;

$fn = 64;

n = len(widths);
wmax = widths[n - 1] + relief;
rows     = ceil(n / per_row);
row_h    = slot_len + relief + 5 + 6;        // slot, edge below, numbers above
coupon_x = 2 * edge + (per_row - 1) * pitch + wmax;
coupon_y = rows * row_h + 4;

module slot2d(w, len) {
    hull() for (y = [w / 2, len - w / 2])
        translate([0, y]) circle(d = w);
}

difference() {
    cube([coupon_x, coupon_y, plate_t]);
    for (i = [0 : n - 1]) {
        w  = widths[i];
        cx = edge + wmax / 2 + (i % per_row) * pitch;
        y0 = floor(i / per_row) * row_h;
        translate([cx, y0 + 5 + relief / 2, 0]) {
            // lead-in, then the land
            hull() {
                translate([0, 0, -0.01]) linear_extrude(0.01)
                    offset(r = lead_in) slot2d(w, slot_len);
                translate([0, 0, lead_in]) linear_extrude(0.01) slot2d(w, slot_len);
            }
            translate([0, 0, -1]) linear_extrude(lead_in + land_w + 1.01)
                slot2d(w, slot_len);
            // relief behind the land: wider, so nothing overhangs
            translate([0, -relief / 2, lead_in + land_w])
                linear_extrude(plate_t)
                    slot2d(w + relief, slot_len + relief);
        }
        // number on the top face
        translate([cx, y0 + 5 + slot_len + relief + 3, plate_t - label_d])
            linear_extrude(label_d + 0.1)
                text(str(i + 1), size = 3.2, halign = "center", valign = "center");
    }
}
