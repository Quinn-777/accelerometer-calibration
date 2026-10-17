// crank.scad
// Scotch-yoke crank for the Phase 2 shake table.
//
// The crank throw IS the motion amplitude, so there is one crank per
// amplitude. Set `amplitude` below, render, export, repeat.
//
//   amplitude = 13 mm  ->  3 to 6 Hz    (0.47 g at 3 Hz, 1.88 g at 6 Hz)
//   amplitude =  9 mm  ->  6 to 9 Hz    (1.30 g at 6 Hz, 2.93 g at 9 Hz)
//   amplitude =  6 mm  ->  9 to 12 Hz   (1.96 g at 9 Hz, 3.48 g at 12 Hz)
//
// Peak acceleration is amplitude * (2*pi*f)^2. The three ranges are chosen so
// every measurement point lands between 0.5 and 3.5 g: high enough above the
// noise floor to be worth reporting, and clear of the +/-4 g full scale. They
// deliberately overlap at 6 and 9 Hz, so those two frequencies can each be
// measured at two different amplitudes. If the two agree, the mechanism is
// behaving; if they do not, something is rattling, and that is worth more
// than either number on its own.
//
// ---------------------------------------------------------------------------
// The pin is printed, and then turned true
//
// The first printed test pin measured 3.82, 4.09 and 3.96 mm at three
// rotational positions: 0.27 mm out of round on a 4 mm pin. That matters
// here more than it would anywhere else, because the pin is rigid with the
// crank and therefore rotates a full turn against the slot every cycle. An
// oval pin injects a position error at exactly the drive frequency - the one
// frequency the measurement cannot separate from real motion.
//
// The fix is to spin the finished crank and sand the pin round:
//   1. Slide a 5 mm rod into the shaft bore and lock it with the set screw,
//      to use as an arbor.
//   2. Chuck the rod in a drill and run it slowly.
//   3. Hold 400 grit against the side of the pin, a few seconds at a time.
//   4. Stop when three caliper readings 60 deg apart agree within 0.05 mm.
// Expect to finish near 4.2 mm.
//
// This is better than pressing in a steel pin, not a fallback from it. What
// the measurement cares about is roundness RELATIVE TO THE ROTATION AXIS,
// and a steel pin pressed into a printed hole inherits whatever eccentricity
// that hole has. Sanding while the part turns on its own axis cannot: it
// removes exactly the error being complained about.
//
// A steel screw was never an option: its threads would chew the slot, and its
// head is an off-centre steel mass driving the frame at the drive frequency.
// The printed pin weighs about 0.2 g, which makes that error roughly 0.3% of
// the drive force instead of 2%.
// ---------------------------------------------------------------------------

amplitude = 13;        // <-- 13, then 9, then 6
land_d    = 5.40;      // <-- set from shaft_test (see "The bore", below)
part      = "crank";   // "crank", or "shaft_test" to print the bore coupon

$fn = 96;

// Printed holes lose somewhere between 0.30 and 0.50 mm on this printer. The
// range is not tighter than that: caliper readings taken inside a hole are
// chords unless the jaws happen to sit on a diameter, and on 2026-10-10 the
// same bore read anywhere from 4.55 to 5.30 depending on how the caliper was
// held. The one firm point is a gauge result - hole S, modelled 5.30, takes
// a 5.00 rod while scraping - which puts the loss near 0.30-0.35.
hole_comp = 0.35;

shaft_d = 5.0;         // NEMA 17 shaft
disc_t  = 14.0;        // grip length on the shaft
pin_d   = 4.5;         // printed oversize: sanding true will take about
                       // 0.3 mm off, and what is left should still be a
                       // generous bearing against the slot
pin_h   = 10.0;
wall    = 3.0;         // material outboard of the pin

// ---------------------------------------------------------------------------
// The amplitude must be MEASURED, not taken from the model
//
// Whatever clearance the bore has, the set screw pushes the shaft to one side
// of it and the crank sits off centre by half of it - a fixed error in the
// amplitude (see "The bore" below for the size). Slot backlash and the
// printer's own error add to it. That is a reason to stop treating the
// modelled throw as the reference. Once the rig is
// assembled, turn the motor by hand to each extreme, push the carriage onto
// the pin in the direction it is travelling, and caliper the gap between the
// carriage end face and the rod block. The difference between the two
// extremes is the real peak-to-peak travel. Calipers give about +/-0.05 mm
// on each reading, so even at the smallest throw that beats the geometry.
//
// The same measurement absorbs slot backlash, which has exactly the same
// character: the carriage swaps slot walls at each force reversal, which
// adds a square wave of the slot clearance at the drive frequency, and its
// fundamental component is 2/pi times the clearance ADDED TO THE AMPLITUDE.
// At 0.10 mm clearance that is 0.064 mm - another 1% at the 6 mm throw,
// frequency-independent, and therefore NOT separable by the f^2 fit the way
// the carriage's rocking is. It has to be measured or it goes straight into
// the scale factor.
//
// The 6 Hz and 9 Hz overlap points give a second, independent handle on it.
// Both errors add a constant d to the throw, so measuring one frequency at
// two throws gives
//     reading_1 / reading_2 = (A1 + d) / (A2 + d)
// which solves for d without assuming either amplitude is right. That is
// what the overlap was for.
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// The bore: two short lands, not one long hole   (CHANGED 2026-10-14)
//
// The earlier versions had a single straight 14 mm hole, modelled 5.30 and
// then 5.55, and the printed crank would not go onto the motor shaft. That
// was predictable from evidence already in hand: rod_fit_test's 12 mm deep
// vertical holes, modelled 5.35 / 5.45 / 5.55, would not take a 5 mm rod at
// ANY of those sizes, while hole S - 5 mm deep, modelled only 5.30 - did.
// Depth is what fails, not diameter: over dozens of layers the hole wanders,
// and the first layers are squashed inward (elephant's foot). Making a deep
// hole bigger does not fix it, which is why the carriage runs on short lands.
// This crank now does the same:
//   - a 4 mm land at each end of the hub, each shallower than hole S;
//   - the 6 mm between them opened up so it never touches the shaft;
//   - a 0.6 mm x 45 deg chamfer where the bore meets the bed, so the
//     elephant's foot has nowhere to close the hole.
// The two lands are 10 mm apart on one axis, which is what keeps the crank
// square to the shaft.
//
// land_d = 5.40 is one 0.10 step above hole S (5.30, zero clearance), i.e.
// about 0.08 mm of clearance. To check it on the real motor shaft, set
// part = "shaft_test": four short hubs with exactly this bore at 5.30 / 5.35
// / 5.40 / 5.45, ten minutes of printing. Put the SMALLEST one that slides
// all the way onto the shaft by hand into land_d.
//
// Why snug matters: the set screw pushes the shaft to one side of whatever
// clearance there is, moving the crank centre by half of it. At 0.08 mm that
// is 0.04 mm - 0.3% of the 13 mm throw, 0.7% of the 6 mm one - against 1-2%
// for the old 5.55 bore. (The real throw is measured after assembly anyway;
// see below.)
// ---------------------------------------------------------------------------
land_w      = 4.0;     // length of each land
relief_d    = 6.2;     // between the lands: clear of the shaft
bed_chamfer = 0.6;     // at the bed-side end of the bore
bore_d      = land_d;  // kept for the set-screw geometry below
// land_fit_test, 2026-10-13: of bosses A-G (modelled 1.65 to 2.55 in 0.15
// steps), an M2 screw cut the best thread in E, modelled 2.25. That is the
// size used for every self-tapped M2 hole in this project.
set_screw_d = 2.25;
set_screw_z = disc_t / 2;
// Only the 5 mm nearest the shaft is tapped; the rest is counterbored, or an
// M2 x 10 screw could not reach the shaft through the 15 mm hub of the
// largest crank. Drive it with a jeweller's screwdriver down the counterbore.
thread_len   = 5.0;
counterbore_d = 5.00;   // -> 4.50..4.70 actual, passes an M2 head and a
                        // jeweller's screwdriver

disc_d  = 2 * (amplitude + pin_d / 2 + wall);

label_depth = 0.6;
label_x     = -(disc_d / 4 + 2);

assert(disc_d / 2 - bore_d / 2 > 4.0,
       "hub wall too thin for the set screw - raise wall");

module pin() {
    cylinder(d1 = pin_d + 2, d2 = pin_d, h = 1.0);          // base flare
    translate([0, 0, 1.0]) cylinder(d = pin_d, h = pin_h - 2.0);
    translate([0, 0, pin_h - 1.0])
        cylinder(d1 = pin_d, d2 = pin_d - 1.2, h = 1.0);    // tip chamfer
}

// The shaft bore for a hub of height h, printed with z = 0 on the bed.
module bore_cut(h) {
    // two lands
    translate([0, 0, -1]) cylinder(d = land_d, h = h + 2);
    // relief between them
    translate([0, 0, land_w]) cylinder(d = relief_d, h = h - 2 * land_w);
    // elephant's-foot chamfer at the bed
    translate([0, 0, -0.01])
        cylinder(d1 = land_d + 2 * bed_chamfer, d2 = land_d, h = bed_chamfer);
}

// Bore coupon: four hubs as tall as the crank's, with the same bore, joined
// by a thin web. Numbered 1-4 on top for 5.30 / 5.35 / 5.40 / 5.45.
test_lands = [5.30, 5.35, 5.40, 5.45];
module shaft_test() {
    for (i = [0 : 3]) translate([i * 15, 0, 0]) difference() {
        cylinder(d = 11, h = disc_t);
        let(land_d = test_lands[i]) {
            translate([0, 0, -1]) cylinder(d = land_d, h = disc_t + 2);
            translate([0, 0, land_w]) cylinder(d = relief_d, h = disc_t - 2 * land_w);
            translate([0, 0, -0.01])
                cylinder(d1 = land_d + 2 * bed_chamfer, d2 = land_d, h = bed_chamfer);
        }
        translate([0, -4.2, disc_t - 0.6]) linear_extrude(1)
            text(str(i + 1), size = 2.4, halign = "center", valign = "center");
    }
    difference() {      // web, 1.2 mm tall, clear of every bore
        translate([0, -1.5, 0]) cube([45, 3, 1.2]);
        for (i = [0 : 3]) translate([i * 15, 0, -1]) cylinder(d = 7.5, h = 3);
    }
}

// Printed with this face down: the pin points up and nothing overhangs, so
// the part needs no support. In use it is flipped, pin towards the yoke.
if (part == "shaft_test") shaft_test();
if (part == "crank")
difference() {
    union() {
        cylinder(d = disc_d, h = disc_t);
        translate([amplitude, 0, disc_t]) pin();
    }

    bore_cut(disc_t);

    // Set screw, entering from the side opposite the pin so a screwdriver
    // can reach it with the crank on the motor.
    translate([0, 0, set_screw_z]) rotate([0, 0, 180]) rotate([0, 90, 0]) {
        cylinder(d = set_screw_d, h = disc_d / 2 + 1);
        translate([0, 0, bore_d / 2 + thread_len])
            cylinder(d = counterbore_d, h = disc_d / 2);
    }

    translate([label_x, 0, disc_t - label_depth])
        linear_extrude(height = label_depth + 0.1)
            text(str(amplitude), size = 5, halign = "center", valign = "center");
}
