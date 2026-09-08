import numpy as np
from PIL import Image
import re
import os

def parse_hex_signed(hex_str):
    """Converts a 16-bit hex string to a signed integer."""
    val = int(hex_str, 16)
    return val - 65536 if val > 32767 else val

# 1. Hardware Subcarrier Allocation
dc_idx    = [0]
guard_idx = list(range(1, 6)) + list(range(123, 128))
pilot_idx = [12, 24, 36, 48, 60, 68, 80, 92, 104]
reserved_bins = set(dc_idx + guard_idx + pilot_idx)
data_idx  = [i for i in range(128) if i not in reserved_bins]

DIM = 64
total_image_bits = DIM * DIM
NUM_PACKETS = int(np.ceil(total_image_bits / len(data_idx))) 
preamble_offset = 128 

raw_payload_data = []

# 2. Extract Real Data Directly
pattern = re.compile(r"ctr\s*:\s*(\d+)\s*\|\s*I:\s*([0-9a-fA-F]+)\s*\|\s*Q:\s*([0-9a-fA-F]+)", re.IGNORECASE)
log_file = "../fft_output_log.txt"

if not os.path.exists(log_file):
    print(f"Error: {log_file} not found.")
    exit()

with open(log_file, "r") as f:
    for line in f:
        match = pattern.search(line)
        if match:
            ctr = int(match.group(1))
            
            # Target all subcarriers across all payload packets (skip the preamble)
            if ctr >= preamble_offset and ctr < (preamble_offset + (NUM_PACKETS * 128)):
                # Only need the Real (I) value
                r_val = parse_hex_signed(match.group(2))
                raw_payload_data.append(r_val)

if len(raw_payload_data) == NUM_PACKETS * 128:
    frames = np.array(raw_payload_data).reshape((NUM_PACKETS, 128))
    raw_symbols = []
    
    # 3. Direct Extraction (NO Phase Correction, NO Descrambling)
    for p in range(NUM_PACKETS):
        rx_frame = frames[p]
        raw_symbols.extend(rx_frame[data_idx])
        
    useful_symbols = np.array(raw_symbols[:total_image_bits], dtype=float)
    
    # 4. Pure 16-bit to 8-bit Grayscale Normalization (NO BPSK Slicing)
    # Scale the raw 16-bit amplitudes directly to 0-255 for image visibility
    min_val = np.min(useful_symbols)
    max_val = np.max(useful_symbols)
    
    if max_val == min_val:
        pixel_array = np.zeros_like(useful_symbols, dtype=np.uint8)
    else:
        pixel_array = (255.0 * (useful_symbols - min_val) / (max_val - min_val)).astype(np.uint8)
        
    recovered_image = pixel_array.reshape((DIM, DIM))
    
    # Save exact pixel grid directly to PNG
    img_out = Image.fromarray(recovered_image, mode='L')
    img_out.save("../raw_16bit_fft_image.png")
    
    print(f"Success: Saved pure {DIM}x{DIM} raw amplitude image to raw_16bit_fft_image.png")
else:
    print(f"Error: Expected {NUM_PACKETS * 128} payload samples, but captured {len(raw_payload_data)}.")