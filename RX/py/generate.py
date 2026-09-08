import numpy as np
from PIL import Image
import matplotlib.pyplot as plt

def generate_ofdm_mem(image_path, n_fft=128, cp_len=32, dim=32, f_cfo_norm=0.0035):
    # 1. Define Indices (0-indexed for Python)
    dc_idx = [0]
    guard_idx = list(range(1, 6)) + list(range(n_fft-5, n_fft))
    pilot_idx = [12, 24, 36, 48, 60, 68, 80, 92, 104]
    
    used_idx = set(dc_idx + guard_idx + pilot_idx)
    data_idx = [i for i in range(n_fft) if i not in used_idx]
    
    num_data_carriers = len(data_idx) # 108 active subcarriers
    
    # Calculate required payload for dim x dim image
    total_image_bits = dim * dim
    data_symbols = int(np.ceil(total_image_bits / num_data_carriers)) 
    required_bits = data_symbols * num_data_carriers 
    
    print(f"Image Bits: {total_image_bits}, Padding: {required_bits - total_image_bits}")
    print(f"Total Data Symbols: {data_symbols}")
    
    # 2. Image Processing to Bits
    img = Image.open(image_path).convert('L').resize((dim, dim))
    img_array = np.array(img)
    binary_img = (img_array > 128).astype(int)
    
    plt.imsave("../tx_ground_truth.png", binary_img, cmap='gray')
    
    input_bits = binary_img.flatten()

    # np.random.seed(42) # Fixed seed ensures TX and RX match
    # prbs_scrambler = np.random.randint(0, 2, len(input_bits))
    # input_bits = np.bitwise_xor(input_bits, prbs_scrambler)
    
    # Pad perfectly to match symbol boundaries
    if len(input_bits) < required_bits:
        padding = np.zeros(required_bits - len(input_bits), dtype=int)
        input_bits = np.concatenate((input_bits, padding))
        
    tx_signal = []
    
    # 3. SYNC SYMBOL (PREAMBLE)
    X_sync = np.zeros(n_fft, dtype=complex)
    sync_data = np.ones(num_data_carriers)
    sync_data[0::2] = -1 
    X_sync[data_idx] = sync_data
    X_sync[pilot_idx] = 1.0 
    
    x_sync = np.fft.ifft(X_sync) * n_fft 
    x_sync_cp = np.concatenate((x_sync[-cp_len:], x_sync))
    tx_signal.extend(x_sync_cp)

    # 4. DATA SYMBOLS (IMAGE)
    bit_ptr = 0
    for _ in range(data_symbols):
        bits = input_bits[bit_ptr : bit_ptr + num_data_carriers]
        bit_ptr += num_data_carriers
        
        data_syms = 2 * bits - 1 # BPSK Mapping
        
        X_data = np.zeros(n_fft, dtype=complex)
        X_data[data_idx] = data_syms
        X_data[pilot_idx] = 1.0 
        
        x_data = np.fft.ifft(X_data) * n_fft
        x_data_cp = np.concatenate((x_data[-cp_len:], x_data))
        tx_signal.extend(x_data_cp)

    tx_signal = np.array(tx_signal)

    # =========================================================================
    # 5. CARRIER FREQUENCY OFFSET INJECTION
    # =========================================================================
    n = np.arange(len(tx_signal))
    phase_rotation = np.exp(1j * 2 * np.pi * f_cfo_norm * n)
    tx_signal = tx_signal * phase_rotation

    # 6. Format for Hardware & Pack to 32-bit Hex
    max_val = np.max(np.abs(np.concatenate((tx_signal.real, tx_signal.imag))))
    scaling_factor = 32767.0 / max_val
    
    tx_real = np.clip(np.round(tx_signal.real * scaling_factor), -32768, 32767).astype(np.int16)
    tx_imag = np.clip(np.round(tx_signal.imag * scaling_factor), -32768, 32767).astype(np.int16)
    
    with open("../cfo_stimulus.mem", "w") as f:
        for r, i in zip(tx_real, tx_imag):
            r_u16 = int(r) & 0xFFFF
            i_u16 = int(i) & 0xFFFF
            packed_32 = (r_u16 << 16) | i_u16
            f.write(f"{packed_32:08x}\n")

    return input_bits

# Execution
tx_bits = generate_ofdm_mem("input.jpeg", dim=32, f_cfo_norm=0)  
# max cfo is  0.0035