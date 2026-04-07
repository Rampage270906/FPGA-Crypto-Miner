`timescale 1ns / 1ps

module uart_top_tb;

    reg clk;
    reg rst;
    reg rx_serial;
    wire tx_serial;

    uart_top uut (
        .clk(clk),
        .rst(rst),
        .rx_serial(rx_serial),
        .tx_serial(tx_serial)
    );

    always #5 clk = ~clk;

    real BIT_TIME = 8680.55;

    task send_byte;
        input [7:0] data;
        integer i;
        begin
            rx_serial = 0; #(BIT_TIME);
            for (i = 0; i < 8; i = i + 1) begin
                rx_serial = data[i];
                #(BIT_TIME);
            end
            rx_serial = 1; #(BIT_TIME);
        end
    endtask

    task recv_byte;
        output [7:0] data;
        integer i;
        begin
            @(negedge tx_serial);
            #(BIT_TIME * 1.5);
            for (i = 0; i < 8; i = i + 1) begin
                data[i] = tx_serial;
                #(BIT_TIME);
            end
        end
    endtask

    reg [255:0] target   = 256'h00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    reg [479:0] header   = 480'h4b1e5e4a29ab5f49ffff001d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    reg [255:0] midstate = 256'hbc909a336358bff090ccac7d1e59caa8c3c8d8e94f0103c896b187364719f91b;

    reg [991:0] full_payload;
    reg [7:0]   recv_data;
    reg [31:0]  final_nonce;
    integer i;

    initial begin
        clk = 0; rst = 1; rx_serial = 1;
        full_payload = {target, header, midstate};

        #100; rst = 0; #100;

        $display("========================================");
        $display("Sending payload over UART...");
        $display("========================================");

        for (i = 123; i >= 0; i = i - 1)
            send_byte(full_payload[i*8 +: 8]);

        $display("[%0t ns] Payload sent. Mining started.", $time);
        $display("Waiting for nonce...");

        recv_byte(recv_data); final_nonce[31:24] = recv_data;
        recv_byte(recv_data); final_nonce[23:16] = recv_data;
        recv_byte(recv_data); final_nonce[15:8]  = recv_data;
        recv_byte(recv_data); final_nonce[7:0]   = recv_data;

        $display("========================================");
        $display("NONCE = 0x%08x (%0d)", final_nonce, final_nonce);
        $display("EXPECTED = 0x000000ec (236)");
        if (final_nonce == 32'h000000ec)
            $display("SUCCESS - EXACT MATCH");
        else
            $display("Different nonce - verify with Python");
        $display("========================================");
        $finish;
    end

    initial begin
        #100000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule