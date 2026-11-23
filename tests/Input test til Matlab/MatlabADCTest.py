import serial, time, csv, os
import numpy as np
from datetime import datetime

PORT    = "/dev/ttyUSB1"
BAUD    = 923077
SAMPLES = 500
SLACK   = 200                                  # extra bytes for resync losses
OUTDIR  = "/home/dintil/Documents/skulating/P3/"

ser = serial.Serial(PORT, BAUD, timeout=3)
time.sleep(0.5)
ser.reset_input_buffer()

t0  = time.perf_counter()
raw = ser.read(2 * SAMPLES + SLACK)
t1  = time.perf_counter()
ser.close()

print("First bytes:", " ".join(f"{b:02X}" for b in raw[:32]))
print(f"Bytes received: {len(raw)}, capture time: {t1 - t0:.3f} s")

buf = np.frombuffer(raw, dtype=np.uint8)

# A frame is valid if byte 0 has bit 7 set and byte 1 has bit 7 clear
idx = np.flatnonzero(buf[:-1] & 0x80)
idx = idx[(buf[idx + 1] & 0x80) == 0]

# Remove overlaps: consecutive accepted frames must be at least 2 bytes apart
if len(idx) > 1:
    keep = np.concatenate(([True], np.diff(idx) >= 2))
    idx = idx[keep]

hi = buf[idx].astype(np.uint16)
lo = buf[idx + 1].astype(np.uint16)
fpga = ((hi & 0x3F) << 6) | (lo & 0x3F)
fpga = fpga[:SAMPLES]

print(f"Valid frames: {len(fpga)} of {SAMPLES}")
if len(fpga) < SAMPLES:
    print(f"Warning: {SAMPLES - len(fpga)} frames missing")

now = datetime.now()
fname = os.path.join(OUTDIR, f"adc_log_{now.strftime('%Y%m%d_%H%M%S')}.csv")
with open(fname, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["Index", "Date", "Time", "Voltage"] + [f"FPGA({i})" for i in range(len(fpga))])
    w.writerow([1, now.strftime("%d.%m.%Y"), now.strftime("%H.%M.%S.%f")[:-3], ""] + fpga.tolist())
print("Saved:", fname)