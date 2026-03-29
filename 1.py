import struct

def sha256_compress(h, chunk):
    K = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]

    def rotr(x, n): return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF

    # THE FIX: Unpack as Little-Endian but process as Big-Endian words
    # This matches the wire-swapping happening in your Verilog
    w = list(struct.unpack("<16I", chunk))
    
    for i in range(16, 64):
        s0 = rotr(w[i-15], 7) ^ rotr(w[i-15], 18) ^ (w[i-15] >> 3)
        s1 = rotr(w[i-2], 17) ^ rotr(w[i-2], 19) ^ (w[i-2] >> 10)
        w.append((w[i-16] + s0 + w[i-7] + s1) & 0xFFFFFFFF)

    a, b, c, d, e, f, g, h_v = h
    for i in range(64):
        S1 = (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) & 0xFFFFFFFF
        ch = ((e & f) ^ ((~e) & g)) & 0xFFFFFFFF
        temp1 = (h_v + S1 + ch + K[i] + w[i]) & 0xFFFFFFFF
        S0 = (rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) & 0xFFFFFFFF
        maj = ((a & b) ^ (a & c) ^ (b & c)) & 0xFFFFFFFF
        temp2 = (S0 + maj) & 0xFFFFFFFF
        h_v, g, f, e, d, c, b, a = g, f, e, (d + temp1) & 0xFFFFFFFF, c, b, a, (temp1 + temp2) & 0xFFFFFFFF
        
    return [(h[0] + a) & 0xFFFFFFFF, (h[1] + b) & 0xFFFFFFFF, (h[2] + c) & 0xFFFFFFFF, (h[3] + d) & 0xFFFFFFFF,
            (h[4] + e) & 0xFFFFFFFF, (h[5] + f) & 0xFFFFFFFF, (h[6] + g) & 0xFFFFFFFF, (h[7] + h_v) & 0xFFFFFFFF]

def get_mining_params(version, prev_hash_hex, merkle_root_hex, timestamp, bits):
    # 1. Reverse hashes for Little Endian (Standard Bitcoin storage)
    prev_le = bytes.fromhex(prev_hash_hex)[::-1]
    merkle_le = bytes.fromhex(merkle_root_hex)[::-1]

    # 2. Construct 80-byte header
    header_part = (
        struct.pack("<I", version) +
        prev_le +
        merkle_le +
        struct.pack("<I", timestamp) +
        struct.pack("<I", bits)
    )

    # 3. Calculate Midstate from first 64 bytes
    h_init = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
    midstate_vals = sha256_compress(h_init, header_part[:64])
    
    # 4. Format outputs for Verilog
    midstate_hex = "".join([format(x, "08x") for x in midstate_vals])
    header_half = header_part[64:76].hex()
    
    exp = bits >> 24
    mant = bits & 0xffffff
    target = mant * (2**(8*(exp - 3)))

    print(f"--- VERILOG READY VALUES ---")
    print(f"midstate           = 256'h{midstate_hex};")
    print(f"block_header_half  = 480'h{header_half}{'0'*96};")
    print(f"target             = 256'h{format(target, '064x')};")

# Genesis Block Inputs
get_mining_params(1, "0"*64, "4a5e1e4ba8b89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b", 1231006505, 0x1d00ffff)