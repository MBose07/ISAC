
# fft outputs image reconstruction

import numpy as np
import matplotlib.pyplot as plt
import re

def parse_hex_signed(hex_str):
    """Converts a 16-bit hex string (e.g., 'ffff') to a signed integer."""
    val = int(hex_str, 16)
    return val - 65536 if val > 32767 else val

# 1. Hardware Subcarrier Allocation
dc_idx    = [0]
guard_idx = list(range(1, 6)) + list(range(123, 128))
pilot_idx = [12, 24, 36, 48, 60, 68, 80, 92, 104]
reserved_bins = set(dc_idx + guard_idx + pilot_idx)
data_idx  = [i for i in range(128) if i not in reserved_bins] # 108 bins

# 2. Dynamic Image & Packet Sizing
DIM = 64 # Change this if your TX image dimensions change
total_image_bits = DIM * DIM
NUM_PACKETS = int(np.ceil(total_image_bits / len(data_idx))) 
preamble_offset = 128 

raw_payload_data = []

# 3. Extract Complex Data (Real + Imaginary) from Verilog Log
# Regex exactly matches: "ctr : 0  | I: ffff | Q: ffff"
pattern = re.compile(r"ctr\s*:\s*(\d+)\s*\|\s*I:\s*([0-9a-fA-F]+)\s*\|\s*Q:\s*([0-9a-fA-F]+)")

with open("../fft_output_log.txt", "r") as f:
    for line in f:
        match = pattern.search(line)
        if match:
            ctr = int(match.group(1))
            
            # Target all subcarriers across all payload packets (skip the preamble)
            if ctr >= preamble_offset and ctr < (preamble_offset + (NUM_PACKETS * 128)):
                r_val = parse_hex_signed(match.group(2))
                i_val = parse_hex_signed(match.group(3))
                raw_payload_data.append(r_val + 1j * i_val)

if len(raw_payload_data) == NUM_PACKETS * 128:
    frames = np.array(raw_payload_data).reshape((NUM_PACKETS, 128))
    equalized_symbols = []
    
    # 4. Dynamic Common Phase Error (CPE) Equalization per Packet
    for p in range(NUM_PACKETS):
        rx_frame = frames[p]
        rx_pilots = rx_frame[pilot_idx]
        
        # Calculate phase drift across the 9 pilots
        mean_cpe = np.mean(np.angle(rx_pilots))
        
        # De-rotate the frame to compensate for the CFO
        corrected_frame = rx_frame * np.exp(-1j * mean_cpe)
        
        # Extract all 108 valid data bins and append
        packet_symbols = np.real(corrected_frame[data_idx])
        equalized_symbols.extend(packet_symbols)
        
    # 5. Truncate padding, Demodulate, and Descramble
    useful_symbols = np.array(equalized_symbols[:total_image_bits])
    
    # BPSK Demodulation: > 0 is Bit 1, < 0 is Bit 0
    recovered_bits = (useful_symbols > 0).astype(int)
    
    # Reverse the TX PRBS Scrambler
    np.random.seed(42) 
    prbs_scrambler = np.random.randint(0, 2, total_image_bits)
    descrambled_bits = np.bitwise_xor(recovered_bits, prbs_scrambler)
    
    # 6. Image Reconstruction
    # Map binary back to visualization amplitudes
    pixel_array = np.where(descrambled_bits > 0.5, 15000.0, -15000.0)
    recovered_image = pixel_array.reshape((DIM, DIM))
    
    plt.imshow(recovered_image, cmap='gray', vmin=-15000, vmax=15000)
    plt.title(f"Equalized FFT Output ({DIM}x{DIM})")
    plt.colorbar(label="Amplitude")
    plt.imsave("../equalized_fft_image.png", recovered_image, cmap='gray')
    plt.show()
    
    print(f"Success: Decoded {len(useful_symbols)} payload bits and rendered the image.")
else:
    print(f"Error: Expected {NUM_PACKETS * 128} payload samples, but captured {len(raw_payload_data)}.")
    print("Ensure the Verilog simulation ran long enough to process all packets.")