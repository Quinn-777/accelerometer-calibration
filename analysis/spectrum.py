"""Power spectral density of burst_log records, by accelerometer bandwidth.

Why a spectrum and not a standard deviation.

The obvious way to check that ACCEL_CONFIG2 really sets the accelerometer's
bandwidth is to hold the sensor still, capture at two filter settings, and
compare the noise. That is what was tried first, using the standard deviation
of the difference between consecutive samples, and it gave a confusing answer:
the noise rose from 92 Hz to 184 Hz but then stopped rising at 460 Hz.

Two things were wrong with that test, and both are visible here:

  1. The difference estimator assumes consecutive samples are independent. A
     filter whose corner sits well below the Nyquist frequency smooths the
     sequence, consecutive samples become correlated, and their differences
     shrink. The estimator therefore understates the noise, and understates it
     MORE at narrow bandwidths - exactly the comparison it was being used for.

  2. Sampling at 500 Hz can only show what happens below 250 Hz. The 460 Hz
     setting puts most of its extra noise above that, where this record cannot
     see it.

The spectrum has neither problem. It shows where the filter corner actually
sits, which is the thing being claimed, instead of inferring it from one
summary number.

Usage:
    python analysis/spectrum.py data/*.csv
"""

from __future__ import annotations

import math
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

# A_DLPF_CFG -> 3 dB bandwidth, from the MPU-6500 Register Map rev 2.1.
# Older records were written before the firmware logged the bandwidth itself.
DLPF_BANDWIDTH = {0x0: 460, 0x1: 184, 0x2: 92, 0x3: 41, 0x4: 20, 0x5: 10, 0x6: 5, 0x7: 460}

AXES = ("X", "Y", "Z")

# Ordinal ramp, one hue light to dark, for the ordered bandwidth levels.
RAMP = ["#86b6ef", "#5598e7", "#2a78d6", "#1c5cab", "#0d366b"]
INK = "#0b0b0b"
INK_MUTED = "#52514e"
GRID = "#e3e2de"


def parse(path):
    """Yield (header dict, Nx3 int array) for every record in a capture file."""
    header, rows = None, None
    for line in Path(path).read_text(errors="ignore").splitlines():
        line = line.strip()
        if line.startswith("# rate_hz"):
            header = dict(kv.split("=", 1) for kv in line[1:].split())
            rows = []
        elif line == "# end":
            if rows:
                yield header, np.array(rows, dtype=float)
            header, rows = None, None
        elif rows is not None and line[:1].isdigit():
            parts = line.split(",")
            if len(parts) == 4:
                rows.append([int(v) for v in parts[1:]])
    if rows:
        yield header, np.array(rows, dtype=float)


def bandwidth_of(header):
    if "accel_bw_hz" in header:
        return int(header["accel_bw_hz"])
    return DLPF_BANDWIDTH[int(header["accel_dlpf"], 16) & 0x0F]


def welch(x, fs, nperseg=256):
    """One-sided PSD in counts^2/Hz, Hann window, 50% overlap.

    Written out rather than taken from scipy so the repository needs only
    numpy, and so the normalisation is visible: the window's power is divided
    back out, which is what makes the result a density that can be compared
    between records of different length.
    """
    x = np.asarray(x, dtype=float)
    x = x - x.mean()
    step = nperseg // 2
    starts = range(0, len(x) - nperseg + 1, step)
    window = np.hanning(nperseg)
    scale = 1.0 / (fs * (window ** 2).sum())

    acc = np.zeros(nperseg // 2 + 1)
    count = 0
    for s in starts:
        seg = x[s:s + nperseg] * window
        acc += np.abs(np.fft.rfft(seg)) ** 2
        count += 1
    psd = acc / count * scale
    psd[1:-1] *= 2.0                      # fold the negative frequencies in
    freqs = np.fft.rfftfreq(nperseg, 1.0 / fs)
    return freqs, psd


def band_density(freqs, psd, lo, hi):
    """RMS noise density in counts per root-Hz, averaged over a band."""
    sel = (freqs >= lo) & (freqs <= hi)
    return math.sqrt(psd[sel].mean())


def main(paths):
    # Keyed by (filter bandwidth, sample rate). Records taken at different
    # sample rates cannot be averaged together: their spectra land on
    # different frequency grids, and what is observable differs between them.
    groups = defaultdict(list)
    for path in paths:
        for header, data in parse(path):
            rate = float(header["rate_hz"])
            groups[(bandwidth_of(header), round(rate))].append((rate, data))

    if not groups:
        print("no records found")
        return

    keys = sorted(groups)
    print(f"{len(sum(groups.values(), []))} records in {len(keys)} "
          "(bandwidth, sample rate) conditions\n")

    # Reference band: above the low-frequency environmental peak (the sensor
    # sits on a desk in a building, and that motion dominates below ~10 Hz),
    # and below any filter corner. Noise density here is a property of the
    # sensor rather than of the filter, so it should agree across settings.
    REF_LO, REF_HI = 20.0, 60.0
    # Top band, just under the 250 Hz Nyquist of a 500 Hz record.
    TOP_LO, TOP_HI = 200.0, 240.0

    print(f"noise density in the {REF_LO:.0f}-{REF_HI:.0f} Hz reference band "
          "(counts/sqrt(Hz))")
    print("this should NOT change with the filter setting\n")
    print(f"{'filter':>8} {'sampled':>9} {'records':>8} "
          + " ".join(f"{a:>8}" for a in AXES))
    print("-" * 56)
    for bw, rate in keys:
        per_axis = []
        for ax in range(3):
            vals = [band_density(*welch(d[:, ax], fs), REF_LO, REF_HI)
                    for fs, d in groups[(bw, rate)]]
            per_axis.append(np.mean(vals))
        print(f"{bw:>6} Hz {rate:>7} Hz {len(groups[(bw, rate)]):>8} "
              + " ".join(f"{v:8.3f}" for v in per_axis))

    # Rather than auto-detecting a corner - which is fragile when the curve
    # has no flat passband to measure against - report how much the top of the
    # observable band is attenuated relative to the reference band. A filter
    # whose corner lies inside the record should show a clear drop here; one
    # whose corner lies above Nyquist should show none.
    print(f"\nattenuation at {TOP_LO:.0f}-{TOP_HI:.0f} Hz "
          f"relative to the {REF_LO:.0f}-{REF_HI:.0f} Hz band, X axis")
    print(f"{'filter':>8} {'sampled':>9} {'nyquist':>9} {'ratio':>8}   note")
    print("-" * 72)
    for bw, rate in keys:
        ratios, nyq = [], None
        for fs, data in groups[(bw, rate)]:
            f, p = welch(data[:, 0], fs)
            ratios.append(band_density(f, p, TOP_LO, TOP_HI)
                          / band_density(f, p, REF_LO, REF_HI))
            nyq = fs / 2.0
        r = float(np.mean(ratios))
        if bw > nyq:
            note = f"corner is above the {nyq:.0f} Hz Nyquist - not observable"
        elif r < 0.75:
            note = "attenuated, so the corner is inside the record"
            note += f"  ({20 * math.log10(r):.1f} dB)"
        else:
            note = "no attenuation seen below Nyquist"
        print(f"{bw:>6} Hz {rate:>7} Hz {nyq:>7.0f} Hz {r:>8.2f}   {note}")

    plot(groups, keys)


def plot(groups, keys):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("\nmatplotlib not installed, skipping the figure")
        return

    fig, ax = plt.subplots(figsize=(7.6, 4.6))
    fig.patch.set_facecolor("#fcfcfb")
    ax.set_facecolor("#fcfcfb")

    # Only one sample rate can be shown at a time: different rates put the
    # spectra on different frequency grids and make different bands
    # observable. The fastest set is the informative one.
    top = max(rate for _, rate in keys)
    keys = [k for k in keys if k[1] == top]
    nyquist = top / 2.0
    ax.axvline(nyquist, color=GRID, linewidth=1.4, linestyle=(0, (4, 3)), zorder=1)
    ax.axhline(0.707, color=GRID, linewidth=1.2, linestyle=(0, (2, 3)), zorder=1)
    ax.annotate("-3 dB", xy=(0.0, 0.707), xycoords=("axes fraction", "data"),
                xytext=(2, 3), textcoords="offset points",
                color=INK_MUTED, fontsize=8)
    ax.annotate(f"Nyquist, {nyquist:.0f} Hz", xy=(nyquist, 1.0),
                xycoords=("data", "axes fraction"), xytext=(-6, -12),
                textcoords="offset points", color=INK_MUTED, fontsize=8,
                ha="right", va="top")

    label_anchors = []
    for i, (bw, rate) in enumerate(keys):
        colour = RAMP[min(i, len(RAMP) - 1)]
        # Average the spectra of every record at this setting. With six
        # records at 92 Hz and two at 460 Hz this matters: a single 1000-point
        # record gives a spectrum too ragged to read a roll-off from.
        acc, freqs = None, None
        for fs, data in groups[(bw, rate)]:
            freqs, p = welch(data[:, 0], fs, nperseg=128)
            acc = p if acc is None else acc + p
        amp = np.sqrt(acc / len(groups[(bw, rate)]))
        # Normalise each curve to its own 20-60 Hz passband, so the figure
        # shows how much each filter cuts rather than how much ambient
        # vibration happened to be present while that record was taken.
        amp = amp / np.sqrt((amp[(freqs >= 20) & (freqs <= 60)] ** 2).mean())

        ax.plot(freqs[1:], amp[1:], color=colour, linewidth=2.0,
                label=f"{bw} Hz setting"
                      f"  ({len(groups[(bw, rate)])} record"
                      f"{'s' if len(groups[(bw, rate)]) != 1 else ''})",
                zorder=3 + i, solid_capstyle="round")

        label_anchors.append((bw, colour, freqs, amp))

    # Direct labels, placed at one frequency and then pushed apart in log
    # space so five converging curves do not stack their text on each other.
    anchor_f = 250.0
    picks = []
    for bw, colour, freqs, amp in label_anchors:
        k = int(np.argmin(np.abs(freqs - anchor_f)))
        picks.append([np.log10(amp[k]), bw, colour])
    picks.sort()
    gap = 0.085
    for j in range(1, len(picks)):
        if picks[j][0] - picks[j - 1][0] < gap:
            picks[j][0] = picks[j - 1][0] + gap
    for y, bw, colour in picks:
        ax.annotate(f"{bw} Hz", xy=(anchor_f, 10 ** y), xytext=(7, -3),
                    textcoords="offset points", color=colour,
                    fontsize=9, fontweight="medium", zorder=6)

    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("frequency (Hz)", color=INK_MUTED, fontsize=10)
    ax.set_ylabel("noise density, relative to each curve's 20-60 Hz level",
                  color=INK_MUTED, fontsize=10)
    ax.set_title("What each filter setting actually cuts, sampled at 1 kHz",
                 color=INK, fontsize=12, pad=12, loc="left")

    ax.grid(True, which="both", color=GRID, linewidth=0.7, zorder=0)
    ax.set_axisbelow(True)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(GRID)
    ax.tick_params(colors=INK_MUTED, labelsize=9)

    ax.legend(frameon=False, loc="lower left", fontsize=8.5,
              labelcolor=INK_MUTED, ncol=1, handlelength=1.6,
              borderpad=0.2, labelspacing=0.3)

    fig.tight_layout()
    out = Path(__file__).resolve().parent.parent / "docs" / "figures" / "noise_spectrum.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=160, facecolor=fig.get_facecolor())
    print(f"\nfigure saved to {out}")


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        args = sorted(str(p) for p in (Path(__file__).resolve().parent.parent / "data").glob("*.csv"))
    main(args)
