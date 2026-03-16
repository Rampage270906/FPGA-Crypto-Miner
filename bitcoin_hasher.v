module bitcoin_hasher (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [255:0] midstate,
    input wire [511:0] block_chunk2,
    output wire [255:0] hash_out,
    output wire done
);

    wire [255:0] pass1_hash;
    wire pass1_done;

    // Pass 1: Hash the nonce chunk using the pre-computed midstate
    sha256_block pass1 (
        .clk(clk),
        .rst(rst),
        .H_in(midstate),
        .M_in(block_chunk2),
        .input_valid(start),
        .H_out(pass1_hash),
        .output_valid(pass1_done)
    );

    wire [255:0] standard_H0;
    
    // Fetch initial constants for the second pass
    sha256_H_0 h0_inst (
        .H_0(standard_H0)
    );

    // Standard SHA-256 Padding for a 256-bit message
    // 256 bits of data + 8-bit '1' (0x80) + 184 bits of '0' + 64-bit length (0x100)
    wire [511:0] pass2_block = {pass1_hash, 8'h80, 184'd0, 64'h0000000000000100};

    // Pass 2: Hash the result of Pass 1
    sha256_block pass2 (
        .clk(clk),
        .rst(rst),
        .H_in(standard_H0),
        .M_in(pass2_block),
        .input_valid(pass1_done), // Starts exactly when Pass 1 finishes a stage
        .H_out(hash_out),
        .output_valid(done)
    );

endmodule