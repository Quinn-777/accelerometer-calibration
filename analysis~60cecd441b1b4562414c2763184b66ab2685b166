"""
six_position.py
Six-position static calibration of an MPU-9250/6500 accelerometer.

Each position lists raw readings (counts, +/-4 g range, AFS_SEL = 1) copied
from the serial monitor while the calibration cube rested on one face.
The key names the CUBE face that was pointing up.

Method: for each sensor axis, one position puts it at +1 g and another at
-1 g. The midpoint of the two readings is the zero offset; half their
difference is the scale factor in counts per g. No angle has to be known,
only that the cube faces are square to each other.

Run from the repository root:
    python analysis/six_position.py
"""

from pathlib import Path

import numpy as np

NOMINAL_SCALE = 8192.0  # datasheet counts per g at +/-4 g
AXES = "XYZ"
FIGURE_PATH = Path(__file__).resolve().parent.parent / "docs" / "figures" / "magnitude_check.png"

# 2026-09-20, after re-tightening the mounting screws.
# Each row is one serial-monitor line: (ax, ay, az).
POSITIONS = {
    "+X up": [(-316, -8188, 100), (-326, -8116, 80), (-318, -8182, 58),
              (-320, -8164, 136), (-316, -8150, 78), (-324, -8162, 108)],
    "-X up": [(-22, 8310, -46), (-8, 8270, -24), (-32, 8276, -32),
              (30, 8246, -20), (-22, 8268, -80), (-28, 8274, -42)],
    "+Y up": [(-8368, 240, 518), (-8354, 226, 536), (-8376, 232, 490),
              (-8402, 226, 498), (-8362, 226, 498), (-8382, 228, 480)],
    "-Y up": [(8026, -94, -446), (7964, -104, -388), (7978, -92, -428),
              (7982, -90, -444), (7978, -112, -438), (8014, -64, -426)],
    "+Z up": [(-592, -12, -8072), (-568, 0, -8028), (-610, -4, -8052),
              (-596, 8, -8066), (-588, 24, -8044), (-598, 6, -8008)],
    "-Z up": [(296, 96, 8060), (282, 74, 8018), (332, 116, 8110),
              (280, 94, 8068), (292, 110, 8050), (270, 104, 8066)],
}

# Taken BEFORE re-tightening the mounting screws (12 Sept, and earlier on
# 20 Sept). Not used in the solve, so they act as an out-of-sample check.
EARLIER = {
    "+Z up, 12 Sep": [(-562, 38, -8062), (-578, 16, -8032), (-590, 22, -8080),
                      (-542, 22, -8072), (-596, 38, -8014), (-544, 48, -8004)],
    "+Z up, 20 Sep": [(-574, 86, -8052), (-648, 0, -8066), (-584, 12, -8066),
                      (-622, 52, -8046), (-606, 44, -8092), (-606, 0, -8068)],
    "-Z up, 20 Sep": [(254, 64, 8054), (266, 42, 8034), (240, 18, 8078),
                      (250, 68, 8082), (256, 62, 8068), (222, 60, 8064)],
}

# Independent validation: rest the cube at arbitrary tilts and paste the
# averaged readings here, one (ax, ay, az) tuple per orientation.
# After calibration every one should be ~1.000 g.
#
# 2026-09-20, means of six serial-monitor rows each.
# A cube balanced on one corner was also tried and rejected: its readings
# wandered by 130-320 counts (normal noise is ~20), so it was not at rest.
RANDOM_ORIENTATIONS = [
    (5087.0, 1.3, -6195.3),      # leaning on a wallet
    (6037.3, -7.7, -5254.0),
    (165.0, 8257.7, 257.3),      # only ~3 deg from the "-X up" position: weak test
    (4.0, 6141.0, -5413.7),
    (5850.7, -3474.7, -4208.0),
    (-4833.0, -2322.7, 6256.3),
    (6232.7, 5155.3, -409.0),
]


def summarise(rows):
    a = np.array(rows, dtype=float)
    return a.mean(axis=0), a.std(axis=0, ddof=1), len(a)


def calibrate(v, offsets, scales):
    return (np.asarray(v, dtype=float) - offsets) / scales


def six_position(means, sds, counts):
    """Offsets, scales and their standard errors. The positions that put
    each axis at +1 g and -1 g are found from the data, which also gives
    the mapping between cube faces and sensor axes."""
    offsets, scales, errors, used = np.zeros(3), np.zeros(3), np.zeros(3), []
    for i in range(3):
        up = max(means, key=lambda k: means[k][i])
        down = min(means, key=lambda k: means[k][i])
        offsets[i] = (means[up][i] + means[down][i]) / 2
        scales[i] = (means[up][i] - means[down][i]) / 2
        errors[i] = np.hypot(sds[up][i] / np.sqrt(counts[up]),
                             sds[down][i] / np.sqrt(counts[down])) / 2
        used.append((up, down))
    return offsets, scales, errors, used


def magnitude_fit(points, offsets, scales):
    """Refit offsets and scales so every position has |a| = 1 g. The
    magnitude does not depend on how the sensor sits in the cube, so this
    removes the cosine error that a mounting tilt puts into the scales."""
    p = np.concatenate([offsets, scales]).astype(float)

    def residual(q):
        return np.array([np.linalg.norm((v - q[:3]) / q[3:]) - 1 for v in points])

    for _ in range(100):
        r = residual(p)
        jac = np.empty((len(r), 6))
        for k in range(6):
            dq = np.zeros(6)
            dq[k] = 1e-3
            jac[:, k] = (residual(p + dq) - r) / 1e-3
        step = np.linalg.lstsq(jac, -r, rcond=None)[0]
        p += step
        if np.max(np.abs(step)) < 1e-7:
            break
    return p[:3], p[3:]


def plot_validation(raw, cal, path=FIGURE_PATH):
    """Dot plot of |a| at each arbitrary orientation, before and after
    calibration, against the true value of 1 g."""
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("  matplotlib not installed, figure skipped (pip install matplotlib)")
        return None

    surface, ink, ink_2, grid = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
    before, after = "#eb6834", "#2a78d6"   # validated categorical slots 2 and 1
    x = np.arange(1, len(raw) + 1)

    fig, ax = plt.subplots(figsize=(7.2, 4.2), dpi=200)
    fig.patch.set_facecolor(surface)
    ax.set_facecolor(surface)

    ax.axhline(1.0, color=ink_2, linewidth=1, alpha=0.7, zorder=1)
    ax.vlines(x, np.minimum(raw, cal), np.maximum(raw, cal),
              color=grid, linewidth=2, zorder=2)
    ax.plot(x, raw, "s", markersize=8, color=before, markeredgecolor=surface,
            markeredgewidth=1.5, zorder=3, label="datasheet scale (8192 counts/g)")
    ax.plot(x, cal, "o", markersize=9, color=after, markeredgecolor=surface,
            markeredgewidth=1.5, zorder=4, label="calibrated (six-position)")

    # direct labels at the right-hand end, plus the reference line
    ax.text(x[-1] + 0.25, raw[-1], "datasheet", color=ink_2, va="center", fontsize=9)
    ax.text(x[-1] + 0.25, cal[-1], "calibrated", color=ink, va="center", fontsize=9)
    ax.text(0.55, 1.0, "1 g", color=ink_2, va="bottom", ha="left", fontsize=9)

    spread_raw = 100 * np.std(raw, ddof=1)
    spread_cal = 100 * np.std(cal, ddof=1)
    ax.set_title("Measured gravity at arbitrary orientations",
                 loc="left", color=ink, fontsize=12, fontweight="bold", pad=40)
    ax.text(0, 1.105, f"Spread across {len(raw)} orientations: "
            f"{spread_raw:.2f}% with the datasheet scale, {spread_cal:.2f}% calibrated",
            transform=ax.transAxes, color=ink_2, fontsize=9)

    ax.set_xticks(x)
    ax.set_xlim(0.4, len(raw) + 1.4)
    lo = min(raw.min(), cal.min()) - 0.004
    hi = max(raw.max(), cal.max()) + 0.004
    ax.set_ylim(lo, hi)
    ax.set_xlabel("Orientation", color=ink_2, fontsize=9)
    ax.set_ylabel("|a|  (g)", color=ink_2, fontsize=9)
    ax.yaxis.set_major_formatter(plt.FormatStrFormatter("%.3f"))
    ax.tick_params(colors=ink_2, labelsize=8, length=0)
    ax.grid(axis="y", color=grid, linewidth=0.8)
    ax.set_axisbelow(True)
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color(grid)
    ax.legend(loc="lower left", bbox_to_anchor=(-0.01, 1.0), ncol=2,
              frameon=False, fontsize=8, labelcolor=ink_2, handletextpad=0.3)

    path.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(path, facecolor=surface)
    plt.close(fig)
    return path


def main():
    stats = {k: summarise(rows) for k, rows in POSITIONS.items()}
    means = {k: s[0] for k, s in stats.items()}
    sds = {k: s[1] for k, s in stats.items()}
    counts = {k: s[2] for k, s in stats.items()}

    print("Position means (counts)")
    for k in POSITIONS:
        m, s = means[k], sds[k]
        print(f"  {k:6s}  ax {m[0]:+8.1f}  ay {m[1]:+8.1f}  az {m[2]:+8.1f}"
              f"   sd {s[0]:4.1f} {s[1]:4.1f} {s[2]:4.1f}")

    offsets, scales, errors, used = six_position(means, sds, counts)

    print("\nAxis mapping (cube face up -> sensor axis at +1 g / -1 g)")
    for i, (up, down) in enumerate(used):
        print(f"  sensor {AXES[i]}: +1 g with cube {up},  -1 g with cube {down}")

    print("\nSix-position solution")
    for i in range(3):
        dev = 100 * (scales[i] - NOMINAL_SCALE) / NOMINAL_SCALE
        print(f"  {AXES[i]}: offset {offsets[i]:+7.1f} counts ({offsets[i] / scales[i]:+.4f} g)"
              f"   scale {scales[i]:7.1f} counts/g ({dev:+.2f}% vs datasheet)"
              f"   1 SE {errors[i]:.1f} counts")

    # In each pair the two horizontal axes should not move. Whatever part of
    # their reading reverses when the cube flips is a tilt; the part that
    # stays is another estimate of their offset.
    print("\nOffset cross-check (same offset, estimated from the other pairs)")
    angle = {}
    for j in range(3):
        estimates = []
        for i, (up, down) in enumerate(used):
            if i == j:
                continue
            estimates.append(f"{(means[up][j] + means[down][j]) / 2:+.1f}")
            flip = (means[up][j] - means[down][j]) / 2
            angle[(i, j)] = np.degrees(np.arcsin(flip / scales[j]))
        print(f"  {AXES[j]}: {offsets[j]:+.1f}   from other pairs: {', '.join(estimates)}")

    print("\nMounting misalignment (each rotation seen by two pairs)")
    for k in range(3):
        i, j = [a for a in range(3) if a != k]
        a1, a2 = angle[(i, j)], angle[(j, i)]
        rigid = "consistent" if a1 * a2 < 0 else "CHECK: same sign"
        print(f"  about sensor {AXES[k]}: {abs(a1):.2f} deg and {abs(a2):.2f} deg  ({rigid})")

    fit_offsets, fit_scales = magnitude_fit(list(means.values()), offsets, scales)
    print("\nMagnitude-constrained fit (removes tilt cosine error)")
    for i in range(3):
        shift = 100 * (fit_scales[i] - scales[i]) / scales[i]
        print(f"  {AXES[i]}: offset {fit_offsets[i]:+7.1f}   scale {fit_scales[i]:7.1f}"
              f"   ({shift:+.2f}% vs six-position)")

    print("\nOut-of-sample check: readings from before re-tightening")
    for k, rows in EARLIER.items():
        m = summarise(rows)[0]
        raw = np.linalg.norm(m) / NOMINAL_SCALE
        cal = np.linalg.norm(calibrate(m, offsets, scales))
        print(f"  {k:14s}  datasheet scale |a| = {raw:.4f} g   calibrated |a| = {cal:.4f} g")

    if RANDOM_ORIENTATIONS:
        print("\nIndependent validation: arbitrary orientations")
        mags = np.array([np.linalg.norm(calibrate(v, offsets, scales))
                         for v in RANDOM_ORIENTATIONS])
        for n, g in enumerate(mags, 1):
            print(f"  {n:2d}  |a| = {g:.4f} g")
        raw = np.array([np.linalg.norm(v) / NOMINAL_SCALE for v in RANDOM_ORIENTATIONS])
        for label, v in (("datasheet scale", raw), ("calibrated", mags)):
            sd = v.std(ddof=1) if len(v) > 1 else 0.0
            print(f"  {label:15s}  mean {v.mean():.4f} g   spread (sd) {sd:.4f} g"
                  f"   worst {np.max(np.abs(v - 1)) * 100:.2f}% from 1 g")
        if len(mags) > 1:
            saved = plot_validation(raw, mags)
            if saved:
                print(f"  figure saved to {saved}")
    else:
        print("\nRANDOM_ORIENTATIONS is empty: add arbitrary-tilt readings to run the validation.")


if __name__ == "__main__":
    main()
