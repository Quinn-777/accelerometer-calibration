// rod_block.scad
// End blocks for the two 5 mm guide rods. Print TWO blocks and TWO caps; the
// block is symmetric in x, so both ends use the same STL - nothing is
// mirrored.
//
// Coordinates match motor_mount.scad and carriage.scad:
//   x  travel      y  along the motor shaft      z  up from the base board
//
// ---------------------------------------------------------------------------
// Why a V and a flat cap rather than a bore or a round groove
//
// A 12 mm deep printed bore on this machine will not take the 5 mm rod at
// any modelled size that was tried, and no caliper reading tells us what
// size it really is - rocking the jaws inside one bore gave 4.55 to 5.30,
// because anything off a true diameter measures a chord. A bore is
// therefore out of the question here - and so is a half-round groove,
// because if the groove prints
// undersize the rod perches on its edges and sits high, and if it prints
// oversize the rod can roll sideways and the two rods are no longer 30.00 mm
// apart. The carriage would bind on that error.
//
// A 90 degree V does not care. The rod touches two flanks, so its CENTRE
// sits on the V's bisector no matter how much the flanks have shifted:
// the rod spacing is exactly what the model says. Shrinkage only moves the
// rod up or down, by about 1.4 times the flank error, and it moves BOTH rods
// by the same amount, so they stay parallel and level with each other.
// A V cut from the top also prints with every layer narrower than the one
// below it, so there is no overhang anywhere.
//
// The cap is then just a flat bar with a shallow rectangular relief over each
// rod. The rod stands 2.5 mm proud of the block; the relief is 2.3 mm deep,
// so the cap grips the rod 0.2 mm before it would touch the block. That 0.2
// mm is a Z dimension, set by layer height, which is the one dimension this
// printer gets right.
//
// ---------------------------------------------------------------------------
// Set-up geometry, worth getting right before any data is taken
//
// Rod length 100 mm, gripped over 10 mm in each block, so the free span is
// 80 mm. Place the Vs so the rods run from x = -27 to x = +73: the left wall
// then occupies x = -27..-17 and the right wall x = 63..73. The 46 mm
// carriage centred at x = 23 has 17 mm of clearance to each wall, against the
// 13 mm it needs at the largest crank throw.
//
// shaft_z is shared with motor_mount.scad on purpose. When the rod axes sit
// at the crank's rotation height, the pin bears on the yoke slot at rod
// height exactly when the drive force peaks, and furthest from it exactly
// when the force passes through zero. The pitching moment on the carriage is
// then proportional to
//     F(t) * y(t) = -m*A^2*w^2 * cos(wt) * sin(wt) = -(m*A^2*w^2/2)*sin(2wt)
// which has no component at the drive frequency - it is a pure second
// harmonic, and lands in the harmonic-distortion sweep where the rig is
// already being checked.
//
// That is only the moment from the PIN. The carriage's own inertia acts at
// its centre of mass, and the sensor sits about 9 mm above the rod axes, so
// there is a separate moment m*a*h that does sit at the drive frequency.
// Levelling the rods does not remove that one. What it removes is the much
// larger term, the one proportional to A rather than to h, and A is 13 mm
// against h = 9 mm at the worst crank. See carriage.scad for why the size of
// the resulting tilt is set by bore clearance rather than by either moment.
//
// Shrinkage will put the rods a few tenths above that ideal height. Once it
// is built, caliper the rod height and the motor shaft height from the base
// board; if they differ by more than about 0.3 mm, shim the lower one. Card
// stock is 0.25 mm.
//
// Mount both blocks and the motor on ONE piece of wood, not on separate
// pieces.
// ---------------------------------------------------------------------------

$fn = 64;

// Best estimate, from the only gauge result we have rather than from a
// caliper: hole S is modelled 5.30 and a 5.00 rod enters it scraping, so a
// shallow bore loses about 0.30-0.35 mm. Used here only for the V, which is
// insensitive to it, and for the base-board holes, which are clearance.
hole_comp = 0.35;

rod_d       = 5.0;
shaft_z     = 26.0;    // MUST match motor_mount.scad and carriage.scad
rod_spacing = 30.0;    // MUST match carriage.scad

grip        = 10.0;    // how much rod the block holds
flange_x    = 40.0;
flange_t    = 6.0;
y0          = -9.0;
y1          = rod_spacing + 9.0;

cap_t       = 5.0;
relief_w    = 6.0;     // width of the cap's relief over each rod
relief_d    = 2.3;     // depth - rod stands 2.5 proud, so this grips by 0.2

// Finished modelled numbers, chosen to survive anywhere in the 0.30-0.50
// shrinkage range rather than tuned to one value. land_fit_test prints
m2_clear = 2.75;       // -> 2.25..2.45 actual
// land_fit_test, 2026-10-13: of bosses A-G (modelled 1.65 to 2.55 in 0.15
// steps), an M2 screw cut the best thread in E, modelled 2.25. That is the
// size used for every self-tapped M2 hole in this project.
m2_tap   = 2.25;
board_screw_d = 4.20;  // -> 3.70..3.90 actual

screw_y = [-5.0, rod_spacing / 2, rod_spacing + 5.0];

wall_x0 = (flange_x - grip) / 2;
wall_x1 = wall_x0 + grip;

// Apex of the 90 degree V, placed so a rod of rod_d resting on both flanks
// has its centre at shaft_z.
v_apex = shaft_z - rod_d / 2 * sqrt(2);
v_top  = shaft_z + 5;

// Print the cap the right way up, reliefs facing the sky.
print_ready = true;

// rotate([90,0,90]) maps the profile's x to machine y and its y to machine z,
// and extrudes along machine x - so the polygon below can be written
// directly in (y, z).
module vee_cuts(len) {
    half = v_top - v_apex;
    for (y = [0, rod_spacing])
        translate([-1, y, 0])
            rotate([90, 0, 90])
                linear_extrude(height = len + 2)
                    polygon([[0, v_apex], [-half, v_top], [half, v_top]]);
}

module cap_reliefs(len) {
    for (y = [0, rod_spacing])
        translate([-1, y - relief_w / 2, shaft_z - 1])
            cube([len + 2, relief_w, relief_d + 1]);
}

brace_w = 10.0;        // braces at the two ends only; a full-width wedge
                       // would be stiffer but doubles the print time

// Brace height above the flange. CHANGED 2026-10-13: the braces used to run
// all the way up the wall (20 mm, to z = 26). The block is used at both ends,
// so one brace always points INWARD, toward the carriage, and reaches 13 mm
// in from the wall. At full stroke with the 13 mm crank the carriage's end
// face comes to 4 mm from the wall, where that brace stood 19.9 mm high -
// above the carriage's underside at z = shaft_z - 9 = 17. Found on the
// assembly check: a 2.9 mm collision every revolution.
// The braces now stop at z = 15, 2 mm under the carriage anywhere in its
// travel. The rods load the wall lightly (friction and the small vertical
// load of the carriage), so a 9 mm brace is ample.
brace_h = 9.0;
carriage_underside_z = shaft_z - 9;   // carriage.scad body_z0
assert(flange_t + brace_h <= carriage_underside_z - 2,
       "braces would reach the carriage at full stroke");

module braces(h, run) {
    for (y = [y0, y1 - brace_w])
        translate([0, y + brace_w, 0])
            rotate([90, 0, 0])
                linear_extrude(height = brace_w)
                    polygon([[0, 0], [run, 0], [0, h]]);
}

module block() {
    difference() {
        union() {
            translate([0, y0, 0])
                cube([flange_x, y1 - y0, flange_t]);
            translate([wall_x0, y0, 0])
                cube([grip, y1 - y0, shaft_z]);
            translate([wall_x1, 0, flange_t])
                braces(brace_h, wall_x0 - 2);
            translate([wall_x0, 0, flange_t])
                mirror([1, 0, 0])
                    braces(brace_h, wall_x0 - 2);
        }

        vee_cuts(flange_x);

        for (y = screw_y)
            translate([flange_x / 2, y, shaft_z - 9])
                cylinder(d = m2_tap, h = 9.5);

        // Four holes down into the base board. They sit between the braces in
        // y and outboard of the wall in x, so a screwdriver can reach all
        // four once the block is standing up. The 30 mm spread in x is the
        // one that matters: the rods pull along x.
        for (x = [5, flange_x - 5], y = [8, rod_spacing - 8])
            translate([x, y, -0.5])
                cylinder(d = board_screw_d, h = flange_t + 1);
    }
}

module cap() {
    difference() {
        translate([wall_x0, y0, shaft_z]) cube([grip, y1 - y0, cap_t]);
        cap_reliefs(flange_x);
        for (y = screw_y)
            translate([flange_x / 2, y, shaft_z - 0.5])
                cylinder(d = m2_clear, h = cap_t + 1);
    }
}

// The V must break through the top face, or the rod cannot be dropped in.
assert(v_top > shaft_z, "the V does not reach the top of the block");
// The cap has to keep some material above its relief.
assert(cap_t - relief_d > 2.0, "cap too thin above the relief");

block();

translate([0, y1 - y0 + 14, 0])
    if (print_ready)
        translate([0, rod_spacing, shaft_z + cap_t])
            rotate([180, 0, 0]) cap();
    else
        cap();
