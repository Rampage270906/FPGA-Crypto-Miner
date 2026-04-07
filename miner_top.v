module miner_top (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [255:0] midstate,
    input wire [479:0] block_header_half,
    input wire [255:0] target,
    output reg nonce_found,
    output reg [31:0] winning_nonce
);
    reg [31:0] current_nonce;
    wire [255:0] current_hash;
    wire hash_valid;

    reg [31:0] nonce_tracker [0:63];

    wire [31:0] nonce_le = {current_nonce[7:0], current_nonce[15:8], current_nonce[23:16], current_nonce[31:24]};

    wire [511:0] full_chunk = {
        block_header_half[479:384],
        nonce_le,
        8'h80,
        312'h0,
        64'h0000000000000280
    };

    bitcoin_hasher hasher_inst (
        .clk(clk),
        .rst(rst),
        .start(start && !nonce_found),
        .midstate(midstate),
        .block_chunk2(full_chunk),
        .hash_out(current_hash),
        .done(hash_valid)
    );

    wire [255:0] hash_reversed;
    genvar j;
    generate
        for (j = 0; j < 32; j = j + 1)
            assign hash_reversed[j*8+7:j*8] = current_hash[(31-j)*8+7:(31-j)*8];
    endgenerate

    // Latency measurement
    reg [31:0] latency_counter;
    reg measuring;
    always @(posedge clk) begin
        if (rst) begin
            latency_counter <= 0;
            measuring <= 0;
        end else if (start && current_nonce == 1) begin
            measuring <= 1;
            latency_counter <= 0;
        end else if (measuring) begin
            latency_counter <= latency_counter + 1;
            if (hash_valid) begin
                $display("PIPELINE LATENCY = %0d cycles", latency_counter);
                measuring <= 0;
            end
        end
    end

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            current_nonce <= 32'd0;
            nonce_found   <= 1'b0;
            winning_nonce <= 32'd0;
            for (i = 0; i <= 63; i = i + 1) nonce_tracker[i] <= 32'd0;
        end else if (start && !nonce_found) begin
            current_nonce    <= current_nonce + 1;
            nonce_tracker[0] <= current_nonce;
            for (i = 0; i < 63; i = i + 1)
                nonce_tracker[i+1] <= nonce_tracker[i];
            if (hash_valid) begin
                if (hash_reversed <= target) begin
                    nonce_found   <= 1'b1;
                    winning_nonce <= nonce_tracker[63];
                end
            end
        end
    end
    reg print_done; // New register to track if we already printed
    always @(posedge clk) begin
        if (rst) begin
            print_done <= 1'b0;
        end else if (nonce_found && !print_done) begin
            $display("MINER: SUCCESS! Nonce found: 0x%08h", winning_nonce);
            print_done <= 1'b1; // This "locks" the print so it only happens once
        end
    end
endmodule