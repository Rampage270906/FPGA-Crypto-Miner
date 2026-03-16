`timescale 1ns / 1ps

module miner_tb;

    reg clk;
    reg rst;
    reg start;
    reg [255:0] target;
    reg [479:0] block_header_half;
    
    wire nonce_found;
    wire [31:0] winning_nonce;

    // Standard SHA-256 starting constants (Fake midstate for testing)
    wire [255:0] standard_H0;
    sha256_H_0 H_init (
        .H_0(standard_H0)
    );

    // DUT
    miner_top uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .midstate(standard_H0),
        .block_header_half(block_header_half),
        .target(target),
        .nonce_found(nonce_found),
        .winning_nonce(winning_nonce)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        
        // Setup an arbitrary 480-bit header
        block_header_half = 480'h6162638000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
        
        // Set an easy difficulty target (Hash must start with 0x0000FFFF...)
        target = 256'h0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

        #25;
        rst = 0;
        
        @(posedge clk);
        start = 1;
        $display("Mining started! Target: %h", target);
    end

    // Monitor for success
    always @(posedge clk) begin
        if (nonce_found) begin
            $display("========================================");
            $display("   BLOCK FOUND!");
            $display("   Winning Nonce: %d (0x%h)", winning_nonce, winning_nonce);
            $display("   Time taken: %0t ns", $time);
            $display("========================================");
            $finish;
        end
    end

    // Timeout safety
    initial begin
        #500000; // Give it plenty of time to grind
        $display("Timeout: No valid nonce found in the given time.");
        $finish;
    end

endmodule