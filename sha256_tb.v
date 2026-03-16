`timescale 1ns / 1ps

module sha256_tb_robust;

    reg clk;
    reg rst;
    reg start;
    reg [511:0] block;

    wire [255:0] hash;
    wire done;

    // DUT
    // Standard SHA-256 starting constants
    // Standard SHA-256 starting constants (for testing)
    wire [255:0] standard_H0;
    sha256_H_0 H_init (
        .H_0(standard_H0)
    );

    // DUT
    bitcoin_hasher uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .midstate(standard_H0), // Inject standard H0 for basic string testing
        .block_chunk2(block),
        .hash_out(hash),
        .done(done)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Arrays to hold test vectors and expected results
    reg [511:0] test_blocks [0:9];     // Changed from [0:2]
    reg [255:0] expected_hashes [0:9]; // Changed from [0:2]

    integer tests_passed = 0;
    integer tests_failed = 0;
    integer hashes_received = 0;

    initial begin
        // Vector 0: "" (Empty string)
        test_blocks[0] = 512'h80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
        expected_hashes[0] = 256'h5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456; 

        // Vector 1: "abc"
        test_blocks[1] = 512'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018;
        expected_hashes[1] = 256'h4f8b42c22dd3729b519ba6f68d2da7cc5b2d606d05daed5ad5128cc03e6c6358; 

        // Vector 2: "hello"
        test_blocks[2] = 512'h68656c6c6f8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000028;
        expected_hashes[2] = 256'h9595c9df90075148eb06860365df33584b75bff782a510c6cd4883a419833d50; 

        // Vector 3: "myfirstSHA"
        test_blocks[3] = 512'h6d796669727374534841800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050;
        expected_hashes[3] = 256'h96082208e341446bb8ba032486d142cbe73f1a66276b96c18ff815f31293fe0d;

        // Vector 4: "" (Empty string - tests pipeline recovery/repetition)
        test_blocks[4] = test_blocks[0];
        expected_hashes[4] = expected_hashes[0];

        // Vector 5: "abc"
        test_blocks[5] = test_blocks[1];
        expected_hashes[5] = expected_hashes[1];

        // Vector 6: "hello"
        test_blocks[6] = test_blocks[2];
        expected_hashes[6] = expected_hashes[2];

        // Vector 7: "myfirstSHA"
        test_blocks[7] = test_blocks[3];
        expected_hashes[7] = expected_hashes[3];

        // Vector 8: "" (Empty string)
        test_blocks[8] = test_blocks[0];
        expected_hashes[8] = expected_hashes[0];

        // Vector 9: "abc"
        test_blocks[9] = test_blocks[1];
        expected_hashes[9] = expected_hashes[1];
    end

    // Input driver thread
    integer i;
    
    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        block = 0;

        #25; // Wait for reset
        rst = 0;

        // Feed all 10 blocks back-to-back
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
            start <= 1;
            block <= test_blocks[i];
        end
        
        // Stop feeding data
        @(posedge clk);
        start <= 0; 
        block <= 0;
    end

    // Output monitor thread
    always @(posedge clk) begin
        if (done) begin
            $display("Time: %0t | Hash [%0d] Output: %h", $time, hashes_received, hash);
            
            if (hash === expected_hashes[hashes_received]) begin
                $display(" -> MATCH!");
                tests_passed = tests_passed + 1;
            end else begin
                $display(" -> MISMATCH! Expected: %h", expected_hashes[hashes_received]);
                tests_failed = tests_failed + 1;
            end

            hashes_received = hashes_received + 1;

            // End simulation after 3 hashes
            if (hashes_received == 10) begin
                $display("\n=============================");
                $display("   SIMULATION COMPLETE");
                $display("   Passed: %0d / 10", tests_passed);
                $display("   Failed: %0d / 10", tests_failed);
                $display("=============================\n");
                $finish;
            end
        end
    end

    // Timeout safety
    initial begin
        #5000;
        $display("FATAL: Simulation Timeout. Pipeline stalled.");
        $finish;
    end

endmodule