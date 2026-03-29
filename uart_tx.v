module uart_tx #(
    parameter CLKS_PER_BIT = 868
)(
    input wire clk,
    input wire rst,
    input wire tx_dv,
    input wire [7:0] tx_byte,
    output reg tx_active,
    output reg tx_serial,
    output reg tx_done
);
    localparam s_IDLE         = 3'b000;
    localparam s_TX_START_BIT = 3'b001;
    localparam s_TX_DATA_BITS = 3'b010;
    localparam s_TX_STOP_BIT  = 3'b011;
    localparam s_CLEANUP      = 3'b100;

    reg [2:0] state;
    reg [15:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] tx_data;

    always @(posedge clk) begin
        if (rst) begin
            state <= s_IDLE;
            clk_count <= 0;
            bit_index <= 0;
            tx_serial <= 1'b1;
            tx_active <= 0;
            tx_done <= 0;
            tx_data <= 0;
        end else begin
            case (state)
                s_IDLE: begin
                    tx_serial <= 1'b1;
                    tx_done <= 0;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (tx_dv) begin
                        tx_active <= 1'b1;
                        tx_data <= tx_byte;
                        state <= s_TX_START_BIT;
                    end
                end

                s_TX_START_BIT: begin
                    tx_serial <= 1'b0;
                    if (clk_count < CLKS_PER_BIT-1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= s_TX_DATA_BITS;
                    end
                end

                s_TX_DATA_BITS: begin
                    tx_serial <= tx_data[bit_index];
                    if (clk_count < CLKS_PER_BIT-1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= s_TX_STOP_BIT;
                        end
                    end
                end

                s_TX_STOP_BIT: begin
                    tx_serial <= 1'b1;
                    if (clk_count < CLKS_PER_BIT-1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= s_CLEANUP;
                    end
                end

                s_CLEANUP: begin
                    tx_done   <= 1'b1; // Pulse done here [cite: 87]
                    tx_active <= 1'b0; // Signal completion [cite: 88]
                    state     <= s_IDLE;
                end

                default: state <= s_IDLE;
            endcase
        end
    end
endmodule