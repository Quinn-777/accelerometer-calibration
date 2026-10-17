// yoke_plate.scad
// The slotted plate of the Scotch yoke. It bolts to the -y face of the
// carriage (the face toward the motor), and the crank pin runs up and down in
// its vertical slot. As the crank turns, the pin's vertical motion is lost in
// the slot and only its horizontal motion reaches the carriage - which is
// what makes the carriage's motion an exact sine wave.
//
// Coordinates are carriage.scad's, so the screw holes line up by
// construction:
//   x  travel (carriage centre at x = 23)
//   y  along the motor shaft; the carriage's front face is at y = -6
//   z  up from the base board; the crank axis is at z = 26
//
// ---------------------------------------------------------------------------
// HOW TO USE IT - one number to set
//
//   1. Print yoke_slot_test.scad (about 15 minutes). It has eight short
//      slots, 1 to 8, modelled 4.30 / 4.40 / ... / 5.00 mm wide, in a plate
//      of this same thickness, printed the same way up.
//   2. Sand the crank pin round (see crank.scad).
//   3. Push the pin into each slot and slide it end to end. Pick the
//      NARROWEST slot it slides along freely, without sticking anywhere.
//      Unlike the carriage lands, do NOT go a size up: there is only one
//      slot, so it cannot bind against a second one, and every 0.1 mm of
//      slack here is backlash in the measurement (see "why tight" below).
//   4. Put that slot's modelled width into slot_w below, export and print.
//
// slot_w = 4.60 is the best guess for a pin sanded to about 4.2 mm: the same
// 0.30-0.35 mm loss as hole S plus about 0.08 mm of clearance.
// ---------------------------------------------------------------------------

slot_w      = 4.60;    // <-- the modelled width of the slot chosen on yoke_slot_test
print_ready = true;    // lay the front face on the bed for export

$fn = 64;

// ---------------------------------------------------------------------------
// Why tight
//
// The pin bears on one wall of the slot while the carriage is pushed one way
// and on the other wall while it is pulled back. Each reversal the carriage
// jumps across the clearance c. That adds a square wave of height c at the
// drive frequency, whose fundamental is 2c/pi ADDED TO THE AMPLITUDE - the
// one error the f^2 fit cannot separate from the real signal. At c = 0.08 mm
// that is 0.05 mm: 0.4% of the 13 mm throw, 0.8% of the 6 mm one. It is
// measured anyway (caliper the real travel; the 6 and 9 Hz overlap points),
// but less of it is better.
// ---------------------------------------------------------------------------

// --- fixed by carriage.scad -------------------------------------------------
shaft_z        = 26.0;
car_cx         = 23.0;    // carriage centre in x (pocket_cx)
car_face_y     = -6.0;    // body_y0: the face this plate bolts to
car_z0         = 17.0;    // carriage underside
car_z1         = 35.0;    // carriage top
seat_w         = 24.0;    // the 1 mm deep seat cut into that face
seat_depth     = 1.0;
plate_screw_dx = 9.0;     // M2 tapped holes in the carriage, at
plate_screw_dz = 5.9;     // x = 23 +/- 9 and z = 26 +/- 5.9

// --- fixed by crank.scad ------------------------------------------------------
max_throw  = 13;          // the largest crank
pin_len    = 10.0;        // includes a 1 mm root flare 2 mm wider than the pin

// --- this part ------------------------------------------------------------------
plate_t    = 10.0;        // the pin engages 9 of its 10 mm
plate_w    = 30.0;
slot_margin = 0.6;        // extra length beyond the pin's travel, each end
slot_half  = max_throw + slot_w / 2 + slot_margin;   // from z = 26
end_wall   = 2.4;         // closed ends: both sides of the slot stay tied
plate_z0   = shaft_z - slot_half - end_wall;
plate_z1   = shaft_z + slot_half + end_wall;

tongue_w   = seat_w - 0.6;     // printed outside edge vs a printed pocket
tongue_t   = seat_depth - 0.1; // sits in the seat, 0.1 mm short of its floor

m2_clear   = 2.75;             // -> about 2.40 actual
head_cb_d  = 4.60;             // counterbore for an M2 head (3.8 mm)
head_cb_h  = 2.5;              // heads sit below the front face: they pass
                               // within 1-2 mm of the spinning crank disc
entry_cham = 1.2;              // 45 deg lead-in on the slot, front face,
                               // so the pin's 1 mm root flare cannot catch

// ---- checks ------------------------------------------------------------------
assert(plate_z0 >= 7.5,
       "plate reaches down to the bracket foot (top at z = 6) - shorten it");
assert(plate_screw_dx - head_cb_d / 2 - slot_w / 2 >= 3.0,
       "screw counterbores too close to the slot");
assert(plate_w / 2 - plate_screw_dx - head_cb_d / 2 >= 1.5,
       "screw counterbores too close to the plate edge");
assert(slot_w >= 4.2 && slot_w <= 5.1,
       "slot_w should be one of the widths on yoke_slot_test: 4.30 to 5.00");

echo(str("slot modelled ", slot_w, " mm wide, z ", shaft_z - slot_half,
         " to ", shaft_z + slot_half, "; plate z ", plate_z0, " to ", plate_z1));

// ---- the plate, in carriage coordinates ---------------------------------------
module slot_cut(w, half, depth_y0, depth_y1) {
    // slot through the thickness, with round ends
    hull() for (z = [shaft_z - half + w / 2, shaft_z + half - w / 2])
        translate([car_cx, depth_y0, z]) rotate([-90, 0, 0])
            cylinder(d = w, h = depth_y1 - depth_y0);
}

module plate() {
    y0 = car_face_y - plate_t;          // front face, toward the crank
    difference() {
        union() {
            translate([car_cx - plate_w / 2, y0, plate_z0])
                cube([plate_w, plate_t, plate_z1 - plate_z0]);
            // tongue into the carriage seat, over the carriage's own height
            translate([car_cx - tongue_w / 2, car_face_y - 0.01, car_z0 + 0.5])
                cube([tongue_w, tongue_t + 0.01, car_z1 - car_z0 - 1]);
        }
        slot_cut(slot_w, slot_half, y0 - 1, car_face_y + seat_depth + 1);
        // 45 deg lead-in around the slot on the front face
        hull() {
            slot_cut(slot_w + 2 * entry_cham, slot_half + entry_cham, y0 - 1, y0);
            slot_cut(slot_w, slot_half, y0 - 1, y0 + entry_cham);
        }
        // four M2 screws into the carriage, heads sunk below the front face
        for (dx = [-1, 1], dz = [-1, 1])
            translate([car_cx + dx * plate_screw_dx, 0, shaft_z + dz * plate_screw_dz]) {
                translate([0, y0 - 1, 0]) rotate([-90, 0, 0])
                    cylinder(d = m2_clear, h = plate_t + tongue_t + 2);
                translate([0, y0 - 1, 0]) rotate([-90, 0, 0])
                    cylinder(d = head_cb_d, h = head_cb_h + 1);
            }
    }
}

// ---- output ------------------------------------------------------------------
if (print_ready)
    // Front face (y = car_face_y - plate_t) down on the bed. rotate([90,0,0])
    // sends y to z, so that face lands at z = car_face_y - plate_t and is
    // lifted back to 0. The counterbores and lead-in are then on the bed
    // side, and the slot walls print as vertical walls with their layer
    // lines running along the slot - the way the pin slides.
    translate([0, 0, -(car_face_y - plate_t)]) rotate([90, 0, 0]) plate();
else
    plate();
