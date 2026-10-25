"""Run the shake table and save each capture straight to a CSV file.

Talks to firmware/shake_log over USB, so nothing has to be copied out of the
Arduino Serial Monitor (which drops lines on a 1000-line paste).

    python analysis/capture.py 3                 # 3 Hz, one capture
    python analysis/capture.py 3 --repeat 3      # 3 Hz, three captures
    python analysis/capture.py 0                 # motor stopped (static record)
    python analysis/capture.py 5 --rate 500 --name 13mm

Each capture is written to data/<name>_<freq>hz_<NN>.csv, numbered so that
nothing is ever overwritten, in the same "# rate_hz=... / i,ax,ay,az /
# end" format as burst_log, so analysis/spectrum.py reads it unchanged.

Close the Arduino IDE Serial Monitor first: only one program can hold the
port. Opening the port resets the Mega, so the script waits for
"shake_log ready" before sending anything. Ctrl+C stops the motor at once.

Needs pyserial:  pip3 install pyserial
"""

from __future__ import annotations

import argparse
import glob
import sys
import time
from pathlib import Path

try:
    import serial
except ImportError:
    sys.exit("pyserial is missing. Run:  pip3 install pyserial")

REPO = Path(__file__).resolve().parent.parent
DATA = REPO / "data"


def find_port() -> str:
    ports = sorted(glob.glob("/dev/cu.usbmodem*") + glob.glob("/dev/cu.usbserial*"))
    if not ports:
        sys.exit("No Arduino found. Is the USB cable plugged in?")
    if len(ports) > 1:
        print("Several ports found, using", ports[0], "- pass --port to choose.")
    return ports[0]


def read_line(ser, timeout: float) -> str | None:
    """One line, or None if nothing arrives within timeout seconds."""
    ser.timeout = timeout
    raw = ser.readline()
    if not raw:
        return None
    return raw.decode("ascii", errors="replace").strip()


def wait_for(ser, text: str, timeout: float, echo: bool = True) -> None:
    end = time.time() + timeout
    while time.time() < end:
        line = read_line(ser, max(0.1, end - time.time()))
        if line is None:
            continue
        if echo and line:
            print("  |", line)
        if line.startswith("Refused"):
            raise RuntimeError(line)
        if text in line:
            return
    raise TimeoutError(f'no "{text}" from the board within {timeout:.0f} s')


def send(ser, cmd: str) -> None:
    ser.write((cmd + "\n").encode("ascii"))
    ser.flush()


def capture_one(ser) -> list[str]:
    """Send g and return the record, from '# rate_hz' to '# end'."""
    send(ser, "g")
    lines: list[str] = []
    end = time.time() + 30
    while time.time() < end:
        line = read_line(ser, 5)
        if line is None:
            continue
        if line.startswith("Not yet"):
            raise RuntimeError(line)
        if line.startswith("# rate_hz"):
            lines = [line]
        elif lines:
            lines.append(line)
            if line == "# end":
                return lines
    raise TimeoutError("capture did not finish")


def header_fields(header: str) -> dict[str, str]:
    return dict(kv.split("=", 1) for kv in header[1:].split() if "=" in kv)


def next_path(stem: str) -> Path:
    n = 1
    while (DATA / f"{stem}_{n:02d}.csv").exists():
        n += 1
    return DATA / f"{stem}_{n:02d}.csv"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("freq", type=float, help="crank frequency in Hz (0 = motor off)")
    ap.add_argument("--repeat", type=int, default=1, help="captures at this frequency")
    ap.add_argument("--rate", type=int, default=500, choices=[100, 200, 250, 500],
                    help="sample rate in Hz (default 500)")
    ap.add_argument("--name", default="13mm", help="file name prefix, e.g. the crank")
    ap.add_argument("--port", default=None, help="serial port (found automatically)")
    args = ap.parse_args()

    DATA.mkdir(exist_ok=True)
    port = args.port or find_port()
    print("Opening", port)

    try:
        ser_cm = serial.Serial(port, 115200, timeout=1)
    except serial.SerialException as e:
        if "busy" in str(e).lower():
            sys.exit("The port is busy: another program has it open - almost always\n"
                     "the Arduino IDE. Quit the Arduino IDE completely (Cmd+Q), then\n"
                     "run this again. To see what holds it:  lsof " + port)
        sys.exit(f"Could not open {port}: {e}")

    motor_started = False
    with ser_cm as ser:
        try:
            try:
                wait_for(ser, "shake_log ready", 10)
            except TimeoutError:
                raise TimeoutError(
                    "the board did not start. Unplug the USB cable, check the four\n"
                    "  sensor wires (a loose one can freeze an older upload of\n"
                    "  shake_log), plug it back in, and re-upload shake_log once.")
            # let the start-up printout finish
            sensor_ok = True
            while (line := read_line(ser, 1.0)) is not None:
                if "WARNING" in line or line.startswith("Check"):
                    print("  |", line)
                    sensor_ok = False
            if not sensor_ok:
                raise RuntimeError("the sensor is not answering - fix the wiring first.")

            send(ser, f"r{args.rate}")
            wait_for(ser, "sample rate", 5)

            if args.freq > 0:
                send(ser, f"{args.freq:g}")
                motor_started = True
                wait_for(ser, "Steady", 60)

            for k in range(args.repeat):
                record = capture_one(ser)
                fields = header_fields(record[0])
                stem = f"{args.name}_{args.freq:g}hz".replace(".", "p")
                path = next_path(stem)
                path.write_text("\n".join(record) + "\n")

                n_rows = len(record) - 3
                print(f"[{k + 1}/{args.repeat}] saved {path.relative_to(REPO)}  "
                      f"shaft_hz={fields.get('shaft_hz')}  rate_hz={fields.get('rate_hz')}  "
                      f"rows={n_rows}  i2c_err={fields.get('i2c_err')}  late={fields.get('late')}")
                rows = [list(map(int, r.split(",")[1:])) for r in record[2:-1]
                        if r[:1].isdigit() and r.count(",") == 3]
                if rows:
                    means = [sum(c) / len(c) for c in zip(*rows)]
                    big = max(range(3), key=lambda i: abs(means[i]))
                    print("  mean counts  X {:+7.0f}   Y {:+7.0f}   Z {:+7.0f}   "
                          "(gravity mostly on {}{})".format(
                              *means, "+" if means[big] > 0 else "-", "XYZ"[big]))
                # The firmware only knows what it COMMANDED. Check that the
                # carriage actually moved: the drive-frequency component of the
                # largest axis should be near the theoretical peak.
                f_sh = float(fields.get("shaft_hz", 0))
                if f_sh > 0 and rows:
                    import cmath, math
                    fs = float(fields["rate_hz"])
                    best = 0.0
                    for ax in range(3):
                        col = [r[ax] for r in rows if any(r)]
                        m = sum(col) / len(col)
                        z = sum((v - m) * cmath.exp(-2j * math.pi * f_sh * k / fs)
                                for k, v in enumerate(col))
                        best = max(best, 2 * abs(z) / len(col))
                    expect = float(fields.get("a_pk_ms2", 0)) / 9.8034 * 8209
                    print(f"  drive-frequency amplitude {best:.0f} counts "
                          f"(theory about {expect:.0f})")
                    if expect > 0 and best < 0.3 * expect:
                        print("  WARNING: the carriage is NOT moving. Check the 24 V supply, "
                              "the crank set screw and the pin in the slot.")
                if fields.get("i2c_err", "0") != "0":
                    print("  WARNING: I2C errors - those samples are zeros. Check the sensor wires.")
                if fields.get("late", "0") != "0":
                    print("  WARNING: late samples - the sample rate was not held.")
                clipped = sum(1 for r in record[2:-1] if r[:1].isdigit()
                              and any(abs(int(v)) >= 32700 for v in r.split(",")[1:]))
                if clipped:
                    print(f"  WARNING: {clipped} samples at the +/-4 g limit - the record is clipped.")
                if n_rows != int(fields.get("n", n_rows)):
                    print("  WARNING: row count does not match n= - lines were lost.")
        except KeyboardInterrupt:
            print("\nCtrl+C - emergency stop")
            send(ser, "x")
            motor_started = False  # already stopped: skip the ramp-down below
        except (RuntimeError, TimeoutError) as e:
            print("Problem:", e)
        finally:
            if motor_started:
                send(ser, "0")
                try:
                    wait_for(ser, "Stopped", 30)
                except TimeoutError:
                    send(ser, "x")
                    print("Did not confirm the stop - sent x.")


if __name__ == "__main__":
    main()
