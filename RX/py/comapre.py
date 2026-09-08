from PIL import Image
import numpy as np

# ==========================================
# INPUT IMAGES
# ==========================================
img1 = np.array(Image.open("../tx_ground_truth.png").convert("L"))
img2 = np.array(Image.open("../decoded.png").convert("L"))

# ==========================================
# CHECK / MATCH IMAGE SIZE
# ==========================================
if img1.shape != img2.shape:
    raise ValueError(
        f"Image sizes differ: {img1.shape} vs {img2.shape}"
    )

# ==========================================
# IMAGE -> BITS
# ==========================================
# Black  = 0
# White  = 1
bits1 = (img1 >= 128).astype(np.uint8)
bits2 = (img2 >= 128).astype(np.uint8)

# ==========================================
# FLATTEN
# ==========================================
bits1 = bits1.flatten()
bits2 = bits2.flatten()

# ==========================================
# BER
# ==========================================
errors = np.sum(bits1 != bits2)
total_bits = len(bits1)

BER = errors / total_bits

print("================================")
print("BER CALCULATION")
print("================================")
print(f"Total bits : {total_bits}")
print(f"Bit errors : {errors}")
print(f"BER        : {BER:.10f}")
print(f"BER (%)    : {BER * 100:.6f}%")