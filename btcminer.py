import serial
import time
import struct

# --- Configure your FPGA COM Port here ---
# Change 'COM3' to the port shown in your Device Manager (e.g., 'COM4', 'COM5')
FPGA_PORT = 'COM3' 
BAUD_RATE = 115200

def run_miner():
    print(f"Connecting to FPGA on {FPGA_PORT}...")
    try:
        # Open the serial port with a 5-second timeout
        ser = serial.Serial(FPGA_PORT, BAUD_RATE, timeout=5)
    except Exception as e:
        print(f"Failed to open port: {e}")
        return

    # 1. Standard SHA-256 Initial Hash Value (H0) - 32 Bytes
    midstate = bytes.fromhex("6A09E667BB67AE853C6EF372A54FF53A510E527F9B05688C1F83D9AB5BE0CD19")
    
    # 2. Dummy Block Header (Chunk 2 minus the 32-bit nonce) - 60 Bytes
    header_hex = "616263800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    header = bytes.fromhex(header_hex)
    
    # 3. Easy Difficulty Target - 32 Bytes
    target = bytes.fromhex("0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
    
    # Pack the payload (Must match the Verilog shift register order: Target -> Header -> Midstate)
    payload = target + header + midstate
    
    print(f"Sending {len(payload)} bytes to FPGA...")
    ser.write(payload)
    
    print("Data sent. Hardware is now mining...")
    
    # Start the timer and wait for the 4-byte response
    start_time = time.time()
    response = ser.read(4)
    end_time = time.time()
    
    if len(response) == 4:
        # Unpack the 4 bytes into a 32-bit unsigned integer (Big-Endian)
        winning_nonce = struct.unpack('>I', response)[0]
        time_taken = end_time - start_time
        
        # Calculate Hash Rate (Hashes per second)
        # We use max(time_taken, 0.0001) to prevent division by zero if it finds it instantly
        hash_rate_hps = winning_nonce / max(time_taken, 0.0001)
        hash_rate_mhs = hash_rate_hps / 1_000_000 # Convert to Megahashes
        
        print("\n========================================")
        print("   BLOCK FOUND BY HARDWARE!")
        print(f"   Winning Nonce: {winning_nonce} (0x{winning_nonce:08x})")
        print(f"   Time taken:    {time_taken:.4f} seconds")
        print(f"   Actual Speed:  {hash_rate_mhs:.2f} MH/s")
        print("========================================")
    else:
        print("\nTimeout: Did not receive a complete 4-byte response.")
        print(f"Received {len(response)} bytes. Ensure the board is programmed and reset.")
        
    ser.close()

if __name__ == "__main__":
    run_miner()