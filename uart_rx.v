module uart_rx #(
    parameter CLKS_PER_BIT = 868 // 100MHz Clock / 115200 Baud Rate
)(
    input wire clk,
    input wire rst,
    input wire rx_serial,
    output reg rx_dv,
    output reg [7:0] rx_byte
);

    localparam s_IDLE         = 3'b000;
    localparam s_RX_START_BIT = 3'b001;
    localparam s_RX_DATA_BITS = 3'b010;
    localparam s_RX_STOP_BIT  = 3'b011;
    localparam s_CLEANUP      = 3'b100;

    reg [2:0] state;
    reg [15:0] clk_count;
    reg [2:0] bit_index;

    always @(posedge clk) begin
        if (rst) begin
            state <= s_IDLE;
            clk_count <= 0;
            bit_index <= 0;
            rx_byte <= 0;
            rx_dv <= 0;
        end else begin
            case (state)
                s_IDLE: begin
                    rx_dv <= 0;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_serial == 1'b0)
                        state <= s_RX_START_BIT;
                    else
                        state <= s_IDLE;
                end

                s_RX_START_BIT: begin
                    if (clk_count == (CLKS_PER_BIT-1)/2) begin
                        if (rx_serial == 1'b0) begin
                            clk_count <= 0;
                            state <= s_RX_DATA_BITS;
                        end else begin
                            state <= s_IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                        state <= s_RX_START_BIT;
                    end
                end

                s_RX_DATA_BITS: begin
                    if (clk_count < CLKS_PER_BIT-1) begin
                        clk_count <= clk_count + 1;
                        state <= s_RX_DATA_BITS;
                    end else begin
                        clk_count <= 0;
                        rx_byte[bit_index] <= rx_serial;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                            state <= s_RX_DATA_BITS;
                        end else begin
                            bit_index <= 0;
                            state <= s_RX_STOP_BIT;
                        end
                    end
                end

                s_RX_STOP_BIT: begin
                    if (clk_count < CLKS_PER_BIT-1) begin
                        clk_count <= clk_count + 1;
                        state <= s_RX_STOP_BIT;
                    end else begin
                        rx_dv <= 1'b1;
                        clk_count <= 0;
                        state <= s_CLEANUP;
                    end
                end

                s_CLEANUP: begin
                    state <= s_IDLE;
                    rx_dv <= 1'b0;
                end

                default: state <= s_IDLE;
            endcase
        end
    end
endmodule