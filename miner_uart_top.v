module miner_uart_top (
    input wire clk,
    input wire rst,         // Map this to a physical button on your board
    input wire rx_serial,   // Map to your board's UART RX pin
    output wire tx_serial   // Map to your board's UART TX pin
);

    // UART RX Signals
    wire rx_dv;
    wire [7:0] rx_byte;
    
    // UART TX Signals
    reg tx_dv;
    reg [7:0] tx_byte;
    wire tx_active;
    wire tx_done;

    // Miner Signals
    reg miner_start;
    wire miner_done;
    wire [31:0] winning_nonce;
    
    // --- NEW: 50 MHz Clock Divider ---
    reg clk_div = 0;
    always @(posedge clk) begin
        clk_div <= ~clk_div;
    end
    
    wire slow_clk;
    BUFG clk_buf (.I(clk_div), .O(slow_clk));
    // ---------------------------------

    // 124-Byte Shift Register (32 Midstate + 60 Header + 32 Target = 124 bytes)
    reg [991:0] data_buffer;
    reg [6:0] byte_counter;
    
    // State Machine
    localparam s_WAIT_FOR_DATA = 3'd0;
    localparam s_START_MINING  = 3'd1;
    localparam s_MINING        = 3'd2;
    localparam s_SEND_NONCE    = 3'd3;
    localparam s_DONE          = 3'd4;
    
    reg [2:0] state;
    reg [2:0] tx_byte_idx; // To send the 4 bytes of the winning nonce

    // Instantiations (Using slow_clk and 434 Baud parameter)
    uart_rx #(.CLKS_PER_BIT(434)) rx_inst (
        .clk(slow_clk), .rst(rst), .rx_serial(rx_serial),
        .rx_dv(rx_dv), .rx_byte(rx_byte)
    );

    uart_tx #(.CLKS_PER_BIT(434)) tx_inst (
        .clk(slow_clk), .rst(rst), .tx_dv(tx_dv), .tx_byte(tx_byte),
        .tx_active(tx_active), .tx_serial(tx_serial), .tx_done(tx_done)
    );

    // FIX: Map the buffer exactly how the miner expects it
    wire [255:0] target   = data_buffer[991:736];
    wire [479:0] header   = data_buffer[735:256];
    wire [255:0] midstate = data_buffer[255:0];

    miner_top miner_inst (
        .clk(slow_clk), .rst(rst), .start(miner_start),
        .midstate(midstate), .block_header_half(header), .target(target),
        .nonce_found(miner_done), .winning_nonce(winning_nonce)
    );

    always @(posedge slow_clk) begin
        if (rst) begin
            state <= s_WAIT_FOR_DATA;
            byte_counter <= 0;
            data_buffer <= 0;
            miner_start <= 0;
            tx_dv <= 0;
            tx_byte_idx <= 0;
        end else begin
            case (state)
                s_WAIT_FOR_DATA: begin
                    if (rx_dv) begin
                        // Shift the new byte into the top of the buffer
                        data_buffer <= {data_buffer[983:0], rx_byte};
                        byte_counter <= byte_counter + 1;
                        
                        if (byte_counter == 123) begin // 124 bytes received (0 to 123)
                            state <= s_START_MINING;
                        end
                    end
                end

                s_START_MINING: begin
                    miner_start <= 1'b1;
                    state <= s_MINING;
                end

                s_MINING: begin
                    // Keep start high, wait for the miner to flag a hit
                    if (miner_done) begin
                        miner_start <= 1'b0;
                        state <= s_SEND_NONCE;
                        tx_byte_idx <= 0;
                    end
                end

                s_SEND_NONCE: begin
                    if (tx_done) begin
                        tx_byte_idx <= tx_byte_idx + 1;
                        if (tx_byte_idx == 3) begin
                            state <= s_DONE;
                        end
                    end else if (!tx_active && !tx_dv) begin
                        tx_dv <= 1'b1;
                        // Send Big-Endian (MSB first)
                        if (tx_byte_idx == 0) tx_byte <= winning_nonce[31:24];
                        if (tx_byte_idx == 1) tx_byte <= winning_nonce[23:16];
                        if (tx_byte_idx == 2) tx_byte <= winning_nonce[15:8];
                        if (tx_byte_idx == 3) tx_byte <= winning_nonce[7:0];
                    end else if (tx_dv) begin
                        tx_dv <= 1'b0; // Pulse tx_dv for 1 clock cycle
                    end
                end

                s_DONE: begin
                    // Idle forever until a hardware reset is pressed to mine a new block
                    state <= s_DONE; 
                end
            endcase
        end
    end
endmodule