module sha256_H_0(
          output [255:0] H_0
          );

      assign H_0 = {
          32'h6A09E667, 32'hBB67AE85, 32'h3C6EF372, 32'hA54FF53A,
          32'h510E527F, 32'h9B05688C, 32'h1F83D9AB, 32'h5BE0CD19
      };

endmodule

module sha256_K_machine (
    input wire [5:0] round,
    output reg [31:0] K0,
    output reg [31:0] K1
);
    always @(*) begin
        case (round[5:1])
            5'd00: begin K0 = 32'h428a2f98; K1 = 32'h71374491; end
            5'd01: begin K0 = 32'hb5c0fbcf; K1 = 32'he9b5dba5; end
            5'd02: begin K0 = 32'h3956c25b; K1 = 32'h59f111f1; end
            5'd03: begin K0 = 32'h923f82a4; K1 = 32'hab1c5ed5; end
            5'd04: begin K0 = 32'hd807aa98; K1 = 32'h12835b01; end
            5'd05: begin K0 = 32'h243185be; K1 = 32'h550c7dc3; end
            5'd06: begin K0 = 32'h72be5d74; K1 = 32'h80deb1fe; end
            5'd07: begin K0 = 32'h9bdc06a7; K1 = 32'hc19bf174; end
            5'd08: begin K0 = 32'he49b69c1; K1 = 32'hefbe4786; end
            5'd09: begin K0 = 32'h0fc19dc6; K1 = 32'h240ca1cc; end
            5'd10: begin K0 = 32'h2de92c6f; K1 = 32'h4a7484aa; end
            5'd11: begin K0 = 32'h5cb0a9dc; K1 = 32'h76f988da; end
            5'd12: begin K0 = 32'h983e5152; K1 = 32'ha831c66d; end
            5'd13: begin K0 = 32'hb00327c8; K1 = 32'hbf597fc7; end
            5'd14: begin K0 = 32'hc6e00bf3; K1 = 32'hd5a79147; end
            5'd15: begin K0 = 32'h06ca6351; K1 = 32'h14292967; end
            5'd16: begin K0 = 32'h27b70a85; K1 = 32'h2e1b2138; end
            5'd17: begin K0 = 32'h4d2c6dfc; K1 = 32'h53380d13; end
            5'd18: begin K0 = 32'h650a7354; K1 = 32'h766a0abb; end
            5'd19: begin K0 = 32'h81c2c92e; K1 = 32'h92722c85; end
            5'd20: begin K0 = 32'ha2bfe8a1; K1 = 32'ha81a664b; end
            5'd21: begin K0 = 32'hc24b8b70; K1 = 32'hc76c51a3; end
            5'd22: begin K0 = 32'hd192e819; K1 = 32'hd6990624; end
            5'd23: begin K0 = 32'hf40e3585; K1 = 32'h106aa070; end
            5'd24: begin K0 = 32'h19a4c116; K1 = 32'h1e376c08; end
            5'd25: begin K0 = 32'h2748774c; K1 = 32'h34b0bcb5; end
            5'd26: begin K0 = 32'h391c0cb3; K1 = 32'h4ed8aa4a; end
            5'd27: begin K0 = 32'h5b9cca4f; K1 = 32'h682e6ff3; end
            5'd28: begin K0 = 32'h748f82ee; K1 = 32'h78a5636f; end
            5'd29: begin K0 = 32'h84c87814; K1 = 32'h8cc70208; end
            5'd30: begin K0 = 32'h90befffa; K1 = 32'ha4506ceb; end
            5'd31: begin K0 = 32'hbef9a3f7; K1 = 32'hc67178f2; end
            default: begin K0 = 32'h0; K1 = 32'h0; end
        endcase
    end
endmodule

module sha256_pipeline_stage_dual #(
    parameter [5:0] ROUND_BASE = 0
)(
    input wire clk,
    input wire rst,
    input wire valid_in,
    input wire [511:0] W_in,
    input wire [255:0] H_in,
    input wire [255:0] H_base_in,
    output reg valid_out,
    output reg [511:0] W_out,
    output reg [255:0] H_out,
    output reg [255:0] H_base_out
);
    // Unpack current H state
    wire [31:0] a = H_in[255:224], b = H_in[223:192], c = H_in[191:160], d = H_in[159:128];
    wire [31:0] e = H_in[127:96],  f = H_in[95:64],   g = H_in[63:32],   h = H_in[31:0];

    // Fetch static constants for this specific stage
    wire [31:0] K0, K1;
    sha256_K_machine k_inst (
        .round(ROUND_BASE[5:0]),
        .K0(K0),
        .K1(K1)
    );

    // Compute W[t+16] (W0_next)
    wire [31:0] W0_tm16 = W_in[511:480];
    wire [31:0] W0_tm15 = W_in[479:448];
    wire [31:0] W0_tm7  = W_in[223:192];
    wire [31:0] W0_tm2  = W_in[63:32];
    wire [31:0] s0_W0tm15 = ({W0_tm15[6:0], W0_tm15[31:7]} ^ {W0_tm15[17:0], W0_tm15[31:18]} ^ (W0_tm15 >> 3));
    wire [31:0] s1_W0tm2  = ({W0_tm2[16:0], W0_tm2[31:17]} ^ {W0_tm2[18:0], W0_tm2[31:19]} ^ (W0_tm2 >> 10));
    wire [31:0] W0_next = (s1_W0tm2 + W0_tm7) + (s0_W0tm15 + W0_tm16);

    // Compute W[t+17] (W1_next) in parallel
    wire [31:0] W1_tm16 = W_in[479:448];
    wire [31:0] W1_tm15 = W_in[447:416];
    wire [31:0] W1_tm7  = W_in[191:160];
    wire [31:0] W1_tm2  = W_in[31:0]; 
    wire [31:0] s0_W1tm15 = ({W1_tm15[6:0], W1_tm15[31:7]} ^ {W1_tm15[17:0], W1_tm15[31:18]} ^ (W1_tm15 >> 3));
    wire [31:0] s1_W1tm2  = ({W1_tm2[16:0], W1_tm2[31:17]} ^ {W1_tm2[18:0], W1_tm2[31:19]} ^ (W1_tm2 >> 10));
    wire [31:0] W1_next = (s1_W1tm2 + W1_tm7) + (s0_W1tm15 + W1_tm16);

    // Round 0 Logic
    wire [31:0] a_mid, b_mid, c_mid, d_mid, e_mid, f_mid, g_mid, h_mid;
    sha256_round round0_inst (
        .Kj(K0), .Wj(W0_tm16),
        .a_in(a), .b_in(b), .c_in(c), .d_in(d), .e_in(e), .f_in(f), .g_in(g), .h_in(h),
        .a_out(a_mid), .b_out(b_mid), .c_out(c_mid), .d_out(d_mid),
        .e_out(e_mid), .f_out(f_mid), .g_out(g_mid), .h_out(h_mid)
    );

    // Round 1 Logic
    wire [31:0] a_next, b_next, c_next, d_next, e_next, f_next, g_next, h_next;
    sha256_round round1_inst (
        .Kj(K1), .Wj(W1_tm16),
        .a_in(a_mid), .b_in(b_mid), .c_in(c_mid), .d_in(d_mid),
        .e_in(e_mid), .f_in(f_mid), .g_in(g_mid), .h_in(h_mid),
        .a_out(a_next), .b_out(b_next), .c_out(c_next), .d_out(d_next),
        .e_out(e_next), .f_out(f_next), .g_out(g_next), .h_out(h_next)
    );

    // Register boundary
    always @(posedge clk) begin
        if (rst) valid_out <= 1'b0;
        else valid_out <= valid_in;
        
        H_base_out <= H_base_in;
        H_out      <= {a_next, b_next, c_next, d_next, e_next, f_next, g_next, h_next};
        W_out      <= {W_in[447:0], W0_next, W1_next}; // Shift left 2 words
    end
endmodule
      
module sha256_S1 (
          input wire [31:0] x,
          output wire [31:0] S1
          );

      assign S1 = ({x[5:0], x[31:6]} ^ {x[10:0], x[31:11]} ^ {x[24:0], x[31:25]});
      endmodule
      
module Ch #(parameter WORDSIZE=0) (
          input wire [WORDSIZE-1:0] x, y, z,
          output wire [WORDSIZE-1:0] Ch
          );

      assign Ch = ((x & y) ^ (~x & z));
      endmodule
      
    module sha256_S0 (
          input wire [31:0] x,
          output wire [31:0] S0
          );

      assign S0 = ({x[1:0], x[31:2]} ^ {x[12:0], x[31:13]} ^ {x[21:0], x[31:22]});
      endmodule
      
 module Maj #(parameter WORDSIZE=0) (
          input wire [WORDSIZE-1:0] x, y, z,
          output wire [WORDSIZE-1:0] Maj
          );

      assign Maj = (x & y) ^ (x & z) ^ (y & z);
      endmodule
      
module sha2_round #(parameter WORDSIZE=0) (
          input [WORDSIZE-1:0] Kj, Wj,
          input [WORDSIZE-1:0] a_in, b_in, c_in, d_in, e_in, f_in, g_in, h_in,
          input [WORDSIZE-1:0] Ch_e_f_g, Maj_a_b_c, S0_a, S1_e,
          output [WORDSIZE-1:0] a_out, b_out, c_out, d_out, e_out, f_out, g_out, h_out
          );

      wire [WORDSIZE-1:0] T1 = h_in + S1_e + Ch_e_f_g + Kj + Wj;
      wire [WORDSIZE-1:0] T2 = S0_a + Maj_a_b_c;

      assign a_out = T1 + T2;
      assign b_out = a_in;
      assign c_out = b_in;
      assign d_out = c_in;
      assign e_out = d_in + T1;
      assign f_out = e_in;
      assign g_out = f_in;
      assign h_out = g_in;
      endmodule
      
module sha256_round (
    input [31:0] Kj, Wj,
    input [31:0] a_in, b_in, c_in, d_in, e_in, f_in, g_in, h_in,
    output [31:0] a_out, b_out, c_out, d_out, e_out, f_out, g_out, h_out
);
    wire [31:0] Ch_e_f_g, Maj_a_b_c, S0_a, S1_e;

    Ch #(.WORDSIZE(32)) Ch (
        .x(e_in), .y(f_in), .z(g_in), .Ch(Ch_e_f_g)
    );
    Maj #(.WORDSIZE(32)) Maj (
        .x(a_in), .y(b_in), .z(c_in), .Maj(Maj_a_b_c)
    );
    sha256_S0 S0 (
        .x(a_in), .S0(S0_a)
    );
    sha256_S1 S1 (
        .x(e_in), .S1(S1_e)
    );

    // Balanced Addition Tree for T1
    wire [31:0] T1_part1 = h_in + S1_e;
    wire [31:0] T1_part2 = Ch_e_f_g + Kj;
    wire [31:0] T1_part3 = T1_part1 + T1_part2;
    wire [31:0] T1       = T1_part3 + Wj;

    // Balanced Addition Tree for T2
    wire [31:0] T2 = S0_a + Maj_a_b_c;

    assign a_out = T1 + T2;
    assign b_out = a_in;
    assign c_out = b_in;
    assign d_out = c_in;
    assign e_out = d_in + T1;
    assign f_out = e_in;
    assign g_out = f_in;
    assign h_out = g_in;

endmodule
      
module sha256_block (
    input wire clk,
    input wire rst,
    input wire [255:0] H_in,
    input wire [511:0] M_in,
    input wire input_valid,
    output wire [255:0] H_out,
    output wire output_valid
);

    wire [511:0] W_stages [0:32];
    wire [255:0] H_stages [0:32];
    wire [255:0] H_base_stages [0:32];
    wire valid_stages [0:32];

    // Pipeline entry
    assign W_stages[0] = M_in;
    assign H_stages[0] = H_in;
    assign H_base_stages[0] = H_in;
    assign valid_stages[0] = input_valid;

    // Generate 32 pipeline stages (2 rounds per stage = 64 rounds)
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : pipe
            sha256_pipeline_stage_dual #(
                .ROUND_BASE(i * 2)
            ) stage_inst (
                .clk(clk),
                .rst(rst),
                .valid_in(valid_stages[i]),
                .W_in(W_stages[i]),
                .H_in(H_stages[i]),
                .H_base_in(H_base_stages[i]),
                .valid_out(valid_stages[i+1]),
                .W_out(W_stages[i+1]),
                .H_out(H_stages[i+1]),
                .H_base_out(H_base_stages[i+1])
            );
        end
    endgenerate

    // Final Addition (H_initial + H_final)
    wire [31:0] a_fin = H_stages[32][255:224] + H_base_stages[32][255:224];
    wire [31:0] b_fin = H_stages[32][223:192] + H_base_stages[32][223:192];
    wire [31:0] c_fin = H_stages[32][191:160] + H_base_stages[32][191:160];
    wire [31:0] d_fin = H_stages[32][159:128] + H_base_stages[32][159:128];
    wire [31:0] e_fin = H_stages[32][127:96]  + H_base_stages[32][127:96];
    wire [31:0] f_fin = H_stages[32][95:64]   + H_base_stages[32][95:64];
    wire [31:0] g_fin = H_stages[32][63:32]   + H_base_stages[32][63:32];
    wire [31:0] h_fin = H_stages[32][31:0]    + H_base_stages[32][31:0];

    // Pipeline exit
    assign H_out = {a_fin, b_fin, c_fin, d_fin, e_fin, f_fin, g_fin, h_fin};
    assign output_valid = valid_stages[32];

endmodule

module sha256_top (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [255:0] midstate,     // NEW: Injected starting state
    input wire [511:0] block_chunk2, // NEW: Only the chunk containing the nonce
    output wire [255:0] hash,
    output wire done
);
    // The pipeline now starts from the injected midstate instead of H0
    sha256_block dut (
        .clk(clk),
        .rst(rst),
        .H_in(midstate),       
        .M_in(block_chunk2),
        .input_valid(start),
        .H_out(hash),
        .output_valid(done)
    );
endmodule
