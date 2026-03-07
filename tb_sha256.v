`timescale 1ns/1ps

module tb_sha256;

    reg clk;
    reg rst;
    reg start;
    reg [511:0] block;

    wire [255:0] hash;
    wire done;

    sha256_top dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .block(block),
        .hash(hash),
        .done(done)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sha256.vcd");
        $dumpvars(0, tb_sha256);
        clk   = 0;
        rst   = 1;
        start = 0;
        block = 512'd0;

        #20 rst = 0;

        // SHA256("abc") — single-line message block
        block = 512'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018;

        #10 start = 1;
        #10 start = 0;

        @(posedge done);
        #1;
        $display("SHA256 = %h", hash);
        $finish;
    end

endmodule
