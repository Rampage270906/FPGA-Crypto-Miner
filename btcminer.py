import serial
import time
import struct

# --- Configure your FPGA COM Port here ---
FPGA_PORT = 'COM6' 
BAUD_RATE = 115200

# --- Define Multiple Test Cases ---
TEST_CASES = [
    {
        "name": "Test Case 1 (Original Header)",
        "midstate": "6A09E667BB67AE853C6EF372A54FF53A510E527F9B05688C1F83D9AB5BE0CD19",
        "header":   "616263800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "target":   "0000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    },
    {
        "name": "Test Case 2 (Modified Header A)",
        "midstate": "6A09E667BB67AE853C6EF372A54FF53A510E527F9B05688C1F83D9AB5BE0CD19",
        "header":   "AAEEFF800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "target":   "0000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    },
    {
        "name": "Test Case 3 (Modified Header B)",
        "midstate": "6A09E667BB67AE853C6EF372A54FF53A510E527F9B05688C1F83D9AB5BE0CD19",
        "header":   "123456800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "target":   "0000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    }
]

def run_miner_tests():
    print(f"Connecting to FPGA on {FPGA_PORT}...")
    try:
        ser = serial.Serial(FPGA_PORT, BAUD_RATE, timeout=100)
    except Exception as e:
        print(f"Failed to open port: {e}")
        return

    print("Connection successful!\n")

    for i, test in enumerate(TEST_CASES):
        print(f"--- Running {test['name']} ---")
        
        # Pause to let the user physically reset the FPGA state machine
        input("PRESS the center reset button (BTNC) on the board, then press ENTER to send data...")
        
        # Flush any junk data in the serial buffers before starting
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        # Pack the payload (Target -> Header -> Midstate)
        target_bytes = bytes.fromhex(test["target"])
        header_bytes = bytes.fromhex(test["header"])
        midstate_bytes = bytes.fromhex(test["midstate"])
        payload = target_bytes + header_bytes + midstate_bytes
        
        ser.write(payload)
        
        start_time = time.time()
        response = ser.read(4)
        end_time = time.time()
        
        if len(response) == 4:
            winning_nonce = struct.unpack('>I', response)[0]
            time_taken = end_time - start_time
            hash_rate_hps = winning_nonce / max(time_taken, 0.0001)
            hash_rate_mhs = hash_rate_hps / 1_000_000 
            
            print(f"   > Block Found!")
            print(f"   > Winning Nonce: {winning_nonce} (0x{winning_nonce:08x})")
            print(f"   > Time taken:    {time_taken:.4f} seconds")
            print(f"   > Apparent Speed:{hash_rate_mhs:.2f} MH/s\n")
        else:
            print(f"   > Timeout: Did not receive a 4-byte response. Received {len(response)} bytes.\n")
            
    ser.close()
    print("All test cases complete. Port closed.")

if __name__ == "__main__":
    run_miner_tests()