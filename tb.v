`timescale 1ns/1ps

module miner_tb;

    reg clk;
    reg rst;
    reg start;
    reg [255:0] midstate;
    reg [479:0] block_header_half;
    reg [255:0] target;

    wire nonce_found;
    wire [31:0] winning_nonce;

    miner_top uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .midstate(midstate),
        .block_header_half(block_header_half),
        .target(target),
        .nonce_found(nonce_found),
        .winning_nonce(winning_nonce)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1; start = 0;
        midstate = 0; block_header_half = 0; target = 0;

        // Genesis block midstate
        midstate = 256'hbc909a336358bff090ccac7d1e59caa8c3c8d8e94f0103c896b187364719f91b;

        // Genesis second chunk: merkle_tail + time + bits (12 bytes)
        // nonce is iterated by miner, so only top 96 bits matter
        block_header_half[479:384] = 96'h4b1e5e4a29ab5f49ffff001d;

        // Genesis target (difficulty 1, very easy)
        // Easy target - find nonce quickly for testing
        target = 256'h00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

        #100; rst = 0; #100;

        @(posedge clk);
        start = 1;
        $display("[%0t ns] Mining started...", $time);

        // Wait for nonce
        @(posedge nonce_found);
        $display("========================================");
        $display("NONCE FOUND: 0x%08x (%0d)", winning_nonce, winning_nonce);
        $display("EXPECTED:    0x1dac2b7c (486604799)");
        if (winning_nonce == 32'h1dac2b7c)
            $display("✅ EXACT MATCH!");
        else
            $display("⚠️  Different nonce - verify validity");
        $display("========================================");
        $finish;
    end

    // Timeout
    initial begin
        #10000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule