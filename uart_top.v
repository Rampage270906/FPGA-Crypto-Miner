module uart_top (
    input wire clk,
    input wire rst,
    input wire rx_serial,
    output wire tx_serial
);

    wire rx_dv;
    wire [7:0] rx_byte;

    uart_rx #(.CLKS_PER_BIT(868)) rx_inst (
        .clk(clk), .rst(rst),
        .rx_serial(rx_serial),
        .rx_dv(rx_dv), .rx_byte(rx_byte)
    );

    reg tx_dv;
    reg [7:0] tx_byte;
    wire tx_active;
    wire tx_done;

    uart_tx #(.CLKS_PER_BIT(868)) tx_inst (
        .clk(clk), .rst(rst),
        .tx_dv(tx_dv), .tx_byte(tx_byte),
        .tx_active(tx_active),
        .tx_serial(tx_serial),
        .tx_done(tx_done)
    );

    reg [991:0] data_buffer;
    reg [6:0]   byte_counter;

    wire [255:0] target            = data_buffer[991:736];
    wire [479:0] block_header_half = data_buffer[735:256];
    wire [255:0] midstate          = data_buffer[255:0];

    reg  miner_start;
    wire miner_done;
    wire [31:0] winning_nonce;
    reg  miner_done_prev;

    miner_top miner_inst (
        .clk(clk), .rst(rst),
        .start(miner_start),
        .midstate(midstate),
        .block_header_half(block_header_half),
        .target(target),
        .nonce_found(miner_done),
        .winning_nonce(winning_nonce)
    );

    localparam s_WAIT_FOR_DATA = 3'd0;
    localparam s_START_MINING  = 3'd1;
    localparam s_MINING        = 3'd2;
    localparam s_SEND_NONCE    = 3'd3;
    localparam s_WAIT_TX_DONE  = 3'd4;
    localparam s_DONE          = 3'd5;

    reg [2:0] state;
    reg [2:0] tx_byte_idx;

    always @(posedge clk) begin
        miner_done_prev <= miner_done;
    end

    always @(posedge clk) begin
        if (rst) begin
            state        <= s_WAIT_FOR_DATA;
            byte_counter <= 0;
            data_buffer  <= 0;
            miner_start  <= 0;
            tx_dv        <= 0;
            tx_byte      <= 0;
            tx_byte_idx  <= 0;
            miner_done_prev <= 0;
        end else begin
            tx_dv <= 1'b0;
            case (state)

                s_WAIT_FOR_DATA: begin
                    if (rx_dv) begin
                        data_buffer  <= {data_buffer[983:0], rx_byte};
                        byte_counter <= byte_counter + 1;
                        if (byte_counter == 123)
                            state <= s_START_MINING;
                    end
                end

                s_START_MINING: begin
                    miner_start <= 1'b1;
                    state       <= s_MINING;
                end

                s_MINING: begin
                    miner_start <= 1'b1;
                    if (miner_done && !miner_done_prev) begin
                        miner_start <= 1'b0;
                        tx_byte_idx <= 0;
                        state       <= s_SEND_NONCE;
                    end
                end

                s_SEND_NONCE: begin
                    if (!tx_active && !tx_done) begin
                        case (tx_byte_idx)
                            3'd0: tx_byte <= winning_nonce[31:24];
                            3'd1: tx_byte <= winning_nonce[23:16];
                            3'd2: tx_byte <= winning_nonce[15:8];
                            3'd3: tx_byte <= winning_nonce[7:0];
                        endcase
                        tx_dv <= 1'b1;
                        state <= s_WAIT_TX_DONE;
                    end
                end

                s_WAIT_TX_DONE: begin
                    if (tx_done) begin
                        if (tx_byte_idx == 3'd3)
                            state <= s_DONE;
                        else begin
                            tx_byte_idx <= tx_byte_idx + 1;
                            state       <= s_SEND_NONCE;
                        end
                    end
                end

                s_DONE: state <= s_DONE;

            endcase
        end
    end
endmodule