// yoke_slot_test.scad
// Fifteen minutes of printing to choose slot_w in yoke_plate.scad.
//
// Nine short slots, numbered 1 to 9, modelled 4.80 to 5.60 mm wide in
// 0.10 mm steps. Each is built exactly like the slot in yoke_plate.scad and
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
// plate's 4.60 slot was 4.1 - 0.5 to 0.7 mm lost. The range is moved up by
// 0.4 mm so that, even if the land only partly fixes this, a pin of
// 4.2-4.8 mm still finds a slot.
//
// The widths differ by only 0.10 mm, so the slots will LOOK identical. That
// is expected. Calipers across the straight middle of a slot are fine
// (it is round holes where they read a chord), but the pin is the gauge.
//
// HOW TO USE IT
//   1. Sand the crank pin round first (see crank.scad), or note that you
//      have not.
//   2. Push the pin into each slot from the chamfered side and slide it from
//      one end of the slot to the other.
//   3. Pick the NARROWEST slot it slides along freely, without sticking.
//      Do not go a size up (see "why tight" in yoke_plate.scad).
//   4. Put that slot's width into slot_w in yoke_plate.scad:
//        1: 4.80   2: 4.90   3: 5.00   4: 5.10   5: 5.20
//        6: 5.30   7: 5.40   8: 5.50   9: 5.60
//   If the pin will not go into 9, or rattles in 1, say so before printing
//   the plate.
//
// PRINT: slice it exactly as it lands - chamfered side down, no supports,
// same settings as the other parts.

widths   = [4.80, 4.90, 5.00, 5.10, 5.20, 5.30, 5.40, 5.50, 5.60];
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
coupon_x = 2 * edge + (n - 1) * pitch + wmax;
coupon_y = slot_len + relief + 2 * 5 + 4;    // room for the numbers

module slot2d(w, len) {
    hull() for (y = [w / 2, len - w / 2])
        translate([0, y]) circle(d = w);
}

difference() {
    cube([coupon_x, coupon_y, plate_t]);
    for (i = [0 : n - 1]) {
        w  = widths[i];
        cx = edge + wmax / 2 + i * pitch;
        translate([cx, 5 + relief / 2, 0]) {
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
        translate([cx, 5 + slot_len + relief + 3, plate_t - label_d])
            linear_extrude(label_d + 0.1)
                text(str(i + 1), size = 3.2, halign = "center", valign = "center");
    }
}
