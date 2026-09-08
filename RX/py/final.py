import numpy as np
import matplotlib.pyplot as plt
import re
import os

# 1. Hardware Subcarrier & Packet Configuration
DIM = 32 # 64x64 image grid layout
DATA_BINS_PER_SYMBOL = 108

# Automatically calculate packets based on image size
total_image_bits = DIM * DIM
NUM_PACKETS = int(np.ceil(total_image_bits / DATA_BINS_PER_SYMBOL)) # Equals 38 for 64x64

# We expect 1 Preamble symbol + NUM_PACKETS Payload symbols
EXPECTED_TOTAL_BITS = (1 + NUM_PACKETS) * DATA_BINS_PER_SYMBOL

raw_demod_bits = []
log_file = "../simulation_log.txt"

if not os.path.exists(log_file):
    print(f"CRITICAL ERROR: Cannot find {log_file}.")
    exit()

# 2. Extract Serial BPSK Bits from the Verilog Log
pattern = re.compile(r"ctr\s*:\s*(\d+)\s*\|\s*Demod Bit:\s*([01])")

with open(log_file, "r") as f:
    for line in f:
        match = pattern.search(line)
        if match:
            bit_val = int(match.group(2))
            raw_demod_bits.append(bit_val)

print(f"Captured Bits: {len(raw_demod_bits)} / {EXPECTED_TOTAL_BITS}")

# --- Safe Padding (Prevents Reshape Crashes) ---
if len(raw_demod_bits) < EXPECTED_TOTAL_BITS:
    missing = EXPECTED_TOTAL_BITS - len(raw_demod_bits)
    print(f"WARNING: Missing {missing} bits. Padding with zeros to allow reshaping.")
    raw_demod_bits.extend([0] * missing)
elif len(raw_demod_bits) > EXPECTED_TOTAL_BITS:
    raw_demod_bits = raw_demod_bits[:EXPECTED_TOTAL_BITS]

# 3. Strip Preamble and Global Padding
bits_array = np.array(raw_demod_bits)

# Reshape into a 2D array: (39 total symbols, 108 bits each)
frames = bits_array.reshape((1 + NUM_PACKETS, DATA_BINS_PER_SYMBOL))

# Discard the very first frame (The Preamble)
payload_frames = frames[1:]

# Flatten all data symbols into a single continuous stream
all_payload_bits = payload_frames.flatten()

# Discard the extra zero-padding bits added at the very end of the TX stream
useful_payload_bits = all_payload_bits[:total_image_bits]

# np.random.seed(42) # Must match the TX seed exactly
# prbs_scrambler = np.random.randint(0, 2, total_image_bits)
# useful_payload_bits = np.bitwise_xor(useful_payload_bits.astype(int), prbs_scrambler)

# 4. Map Binary Stream to Standard Pixel Array (0 to 255)
pixel_array = np.where(useful_payload_bits > 0.5, 255, 0).astype(np.uint8)

# 5. Image Reconstruction and Plotting
recovered_image = pixel_array.reshape((DIM, DIM))

save_path = "../decoded_final_image.png"
plt.imsave(save_path, recovered_image, cmap='gray')

plt.figure(figsize=(6, 6))
fig = plt.gcf()
fig.canvas.manager.set_window_title('BPSK Image Recovery')

plt.imshow(recovered_image, cmap='gray', vmin=0, vmax=255)
plt.title(f"Decoded BPSK Image Recovery ({DIM}x{DIM} Pixels)")
plt.axis('off')
plt.tight_layout()
plt.show()
plt.imsave("../decoded.png", recovered_image, cmap='gray')


print(f"Success: Decoded {len(useful_payload_bits)} payload bits and saved the image.")