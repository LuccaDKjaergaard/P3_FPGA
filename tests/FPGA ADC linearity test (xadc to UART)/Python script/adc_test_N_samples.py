"""
PC Serial Logger for ADC Test (ESP32 Master Output)

This script reads ADC dataset lines from ESP32 over Serial (USB)
and saves them into a CSV file on the Desktop.

ESP32 expected serial line format:
    A<mega_raw>; E<esp_raw>; D<ads_raw>;

Example:
    A436; E1857; D13296;

Workflow:
1) Ask once: number of samples per voltage step (SAMPLES)
2) For each voltage step:
   - User enters voltage manually
   - Script collects SAMPLES serial lines
   - Stores them as one row in CSV

Output CSV structure:
[Index, Date, Time, Voltage, MCP(0..N-1), ARD(0..N-1), ESP(0..N-1)]
"""

import serial
import time
import csv
from datetime import datetime
import os


# ---------------- SERIAL CONFIG ----------------
PORT = "COM12"  # input port
BAUD = 115200 # MUST match baudrate of sender
TIMEOUT = 1 # seconds


# ---------------- ASK SAMPLE COUNT (ONCE) ----------------
while True:
    try:
        SAMPLES = int(input("Enter number of samples per voltage (once): ").strip())
        if SAMPLES <= 0:
            raise ValueError
        break
    except ValueError:
        print("❌ Invalid number, try again")


# ---------------- OPEN SERIAL PORT ----------------
ser = serial.Serial(PORT, BAUD, timeout=TIMEOUT)

# Give ESP32 time to reset after opening serial
time.sleep(2)

print("Serial monitoring started...")


# ---------------- CSV OUTPUT SETUP ----------------
# Save file on Desktop automatically
#desktop_path = os.path.join(os.path.expanduser("~"), "C:\Users\ldybt\Documents\GitHub\P3_FPGA\tests\FPGA ADC linearity test (xadc to UART)")
desktop_path = r"C:\Users\ldybt\Documents\GitHub\P3_FPGA\tests\FPGA ADC linearity test (xadc to UART)"
csv_filename = os.path.join(
    desktop_path,
    f"adc_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
)

file = open(csv_filename, "w", newline="")
writer = csv.writer(file)


# ---------------- CSV HEADER ----------------
# First basic columns
header = ["Index", "Date", "Time", "Voltage"]

# Then add sample columns
#for i in range(SAMPLES):
#    header.append(f"MCP({i})")   # MCP3201 samples
#for i in range(SAMPLES):
#    header.append(f"ARD({i})")   # Arduino Mega samples
#for i in range(SAMPLES):
#    header.append(f"ESP({i})")   # ESP32 ADC samples
for i in range(SAMPLES):
    header.append(f"FPGA({i})")   # FPGA samples

writer.writerow(header)

# Row index counter
index = 1


# ---------------- PARSE FUNCTION ----------------
def parse_line(line: str):
    """
    Parses one dataset line from ESP32.

    Expected input format:
        A436; E1857; D13296;

    Returns:
        (a, e, d)
        a = Arduino Mega raw ADC
        e = ESP32 raw ADC
        d = MCP3201 raw ADC

    If parsing fails, values remain None.
    """
    f = None

    # Remove whitespace, remove last ';', split by ';'
    parts = line.strip().rstrip(";").split(";")

    for p in parts:
        p = p.strip()

        if p.startswith("A"):
            try:
                f = int(p[1:])
            except:
                pass

        """       
        elif p.startswith("E"):
            try:
                e = int(p[1:])
            except:
                pass

        elif p.startswith("D"):
            try:
                d = int(p[1:])
            except:
                pass
        """
    return f


# ---------------- MAIN LOOP ----------------
try:
    while True:

        # User enters voltage
        ut = input("\nEnter voltage (or 'q' to quit): ").strip()

        # Exit condition
        if ut.lower() == "q":
            break

        # Pre-allocate sample arrays
        #mcp = [None] * SAMPLES
        #ard = [None] * SAMPLES
        #esp = [None] * SAMPLES
        fpga = [None] * SAMPLES

        # Clear old serial data before starting new capture
        ser.reset_input_buffer()

        # Throw away everything for 100 ms (~140 lines) to flush the pipeline
        t_end = time.time() + 0.1
        while time.time() < t_end:
            ser.readline()

        print(f"Logging {SAMPLES} samples...")

        count = 0
        while count < SAMPLES:

            # Read one line from serial
            line = ser.readline().decode(errors="ignore").strip()

            # Skip empty lines
            if not line:
                continue

            # Parse the dataset line
            f = parse_line(line)

            # Skip invalid lines
            if f is None:
                continue

            # Store each sample
            #ard[count] = a
            #esp[count] = e
            #mcp[count] = d
            fpga[count] = f

            count += 1
            #print(f"Sample {count:03d}: A:{a} | E:{e} | M:{d}")
            print(f"Sample {count:03d}: F:{f}")

        # Timestamp for this row
        now = datetime.now()

        # Base row fields
        row = [
            index,
            now.strftime("%d.%m.%Y"),
            now.strftime("%H.%M.%S.%f")[:-3],  # milliseconds precision
            ut
        ]

        # Append all sample arrays in order
        #row.extend(mcp)
        #row.extend(ard)
        #row.extend(esp)
        row.extend(fpga)

        # Write row to CSV
        writer.writerow(row)
        file.flush()

        print(f"✔ Row {index} saved")
        index += 1


except KeyboardInterrupt:
    print("\nStopped by user")


finally:
    # Always close resources properly
    file.close()
    ser.close()
    print("Serial closed, file saved.")
