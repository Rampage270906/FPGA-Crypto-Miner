module miner_top (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [255:0] midstate,
    input wire [479:0] block_header_half, // 480 bits (Chunk 2 minus the 32-bit nonce)
    input wire [255:0] target,            // The difficulty target
    output reg nonce_found,
    output reg [31:0] winning_nonce
);
    reg [31:0] current_nonce;
    wire [255:0] current_hash;
    wire hash_valid;

    // Shift register to track nonces through the 64-cycle pipeline latency
    reg [31:0] nonce_tracker [0:64];

    // The 512-bit chunk is the 480-bit header + the 32-bit nonce
    wire [511:0] full_chunk = {block_header_half, current_nonce};

    // Instantiate your double-SHA256 pipeline
    bitcoin_hasher hasher_inst (
        .clk(clk),
        .rst(rst),
        .start(start && !nonce_found), // Stop pushing data if we found a block
        .midstate(midstate),
        .block_chunk2(full_chunk),
        .hash_out(current_hash),
        .done(hash_valid)
    );

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            current_nonce <= 32'd0;
            nonce_found <= 1'b0;
            winning_nonce <= 32'd0;
            for (i = 0; i <= 64; i = i + 1) nonce_tracker[i] <= 32'd0;
        end else if (start && !nonce_found) begin
            // 1. Increment nonce every single clock cycle
            current_nonce <= current_nonce + 1;

            // 2. Shift the tracker array to match pipeline latency
            nonce_tracker[0] <= current_nonce;
            for (i = 0; i < 64; i = i + 1) begin
                nonce_tracker[i+1] <= nonce_tracker[i];
            end

            // 3. Compare hash output to target difficulty
            if (hash_valid) begin
                // If hash is smaller than target, we found a block!
                if (current_hash <= target) begin
                    nonce_found <= 1'b1;
                    winning_nonce <= nonce_tracker[64]; // Retrieve the nonce from 64 cycles ago
                end
            end
        end
    end
endmodule