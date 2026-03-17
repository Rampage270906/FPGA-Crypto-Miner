`timescale 1ns / 1ps

// run simulation then type "run 15ms" in Tcl Console

module miner_uart_top_tb;

    reg clk;
    reg rst;
    reg rx_serial;
    wire tx_serial;

    // Instantiate your Top-Level UART Wrapper
    miner_uart_top uut (
        .clk(clk),
        .rst(rst),
        .rx_serial(rx_serial),
        .tx_serial(tx_serial)
    );

    // Generate 100 MHz clock (10ns period)
    always #5 clk = ~clk;

    // UART bit time in nanoseconds (1 second / 115200 baud = 8680.55 ns)
    real BIT_TIME = 8680.55;

    // Task: Simulate the PC sending a single byte over USB
    task send_byte;
        input [7:0] data;
        integer i;
        begin
            rx_serial = 0; // Start bit
            #(BIT_TIME);
            for (i = 0; i < 8; i = i + 1) begin
                rx_serial = data[i]; // Data bits (LSB first for UART)
                #(BIT_TIME);
            end
            rx_serial = 1; // Stop bit
            #(BIT_TIME);
        end
    endtask

    // Task: Simulate the PC receiving a byte from the FPGA
    task recv_byte;
        output [7:0] data;
        integer i;
        begin
            @(negedge tx_serial); // Wait for start bit
            #(BIT_TIME * 1.5);    // Wait until the middle of the first data bit
            for (i = 0; i < 8; i = i + 1) begin
                data[i] = tx_serial;
                #(BIT_TIME);
            end
        end
    endtask

    // Hardcoded Test Payload (Same as the Python script)
    reg [255:0] target   = 256'h0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    reg [479:0] header   = 480'h6162638000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    reg [255:0] midstate = 256'h6A09E667BB67AE853C6EF372A54FF53A510E527F9B05688C1F83D9AB5BE0CD19;
    
    reg [991:0] full_payload;
    reg [7:0] recv_data;
    reg [31:0] final_nonce;
    integer i;

    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        rx_serial = 1; // UART idle state is high
        full_payload = {target, header, midstate}; // Pack exactly as python does

        #100;
        rst = 0;
        #100;

        $display("----------------------------------------");
        $display("[%0t ns] SIMULATING PC CONNECTION...", $time);
        $display("----------------------------------------");
        
        // Send the 124 bytes (MSB first, slicing 8 bits at a time)
        for (i = 123; i >= 0; i = i - 1) begin
            send_byte(full_payload[i*8 +: 8]);
        end

        $display("[%0t ns] Payload sent! FPGA is now mining.", $time);
        $display("Waiting for TX response...\n");

        // Wait to receive the 4-byte nonce back from the FPGA
        recv_byte(recv_data); final_nonce[31:24] = recv_data;
        recv_byte(recv_data); final_nonce[23:16] = recv_data;
        recv_byte(recv_data); final_nonce[15:8]  = recv_data;
        recv_byte(recv_data); final_nonce[7:0]   = recv_data;

        $display("========================================");
        $display("   BLOCK FOUND BY FULL SYSTEM SIMULATION!");
        $display("   Winning Nonce: %d (0x%08x)", final_nonce, final_nonce);
        $display("   Sim Time: %0t ns", $time);
        $display("========================================");

        $finish;
    end

endmodule