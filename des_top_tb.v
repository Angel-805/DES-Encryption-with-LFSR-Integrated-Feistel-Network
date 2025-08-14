`timescale 1ns/100ps

module des_top_tb;
    
    reg clk;
    reg rst_n;
    reg start;
    reg enc_dec; // 1=ENC, 0=DEC
    reg [63:0] data_in;

    wire [63:0] data_out;
    wire done;
    wire busy;
    wire valid;

    // Test data
    reg [63:0] test_plain;
    reg [63:0] test_cipher;
    reg [63:0] test_roundtrip;
    integer i;

    des_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .enc_dec(enc_dec),
        .data_in(data_in),
        .data_out(data_out),
        .done(done),
        .busy(busy),
        .valid(valid)
    );

    // Clock
    always #5 clk = ~clk;

    //convert state nums to words
    reg [2:0] prev_state;
    function [128*8-1:0] state_name; // printable label
        input [2:0] s;
        begin
            case (s)
                3'd0: state_name = "IDLE";
                3'd1: state_name = "INIT";
                3'd2: state_name = "ROUND";
                3'd3: state_name = "OUT_LATCH";
                3'd4: state_name = "OUT_DONE";
                3'd5: state_name = "WAIT";
                default: state_name = "???";
            endcase
        end
    endfunction

    // Print state transitions once
    always @(posedge clk) if (rst_n && dut.state !== prev_state) begin
        $display("Time %0t  STATE -> %0s", $time, state_name(dut.state));
        prev_state <= dut.state;
    end

    //gets exact data_in in L/R
    always @(posedge dut.seed) begin

        //show data flow
        $display("\n Time %0t  [SEED] data_in=%h", $time, data_in);
        $display("\tInput_reg: in_L=%h  in_R=%h", dut.in_L, dut.in_R);
        $display("\t L/R regs : L_q=%h R_q=%h (loaded)\n", dut.L_q, dut.R_q);
        
    end

    //prints inputs for each round, keys and outputs
    //skip seed
    always @(posedge clk) if (dut.round_en) begin : ROUND_PRINT
        integer key_idx;
        key_idx = dut.enc_dec ? dut.round_cnt : (3'd7 - dut.round_cnt);
        $display("Time %0t  [R%0d %s] L_in=%h  R_in=%h  | K[%0d]=%012h, L_next=%h  R_next=%h",
                 $time, dut.round_cnt, (enc_dec ? "ENC":"DEC"),
                 dut.L_q, dut.R_q,
                 key_idx, dut.round_key,
                 dut.L_out, dut.R_out);
    end

    //two stage monitor matching FSM outs
    //verifies timing
    always @(posedge dut.output_sig) begin
       
        $display("\nTime %0t  [OUT_LATCH] Output_reg.load=1  left_in(L_q)=%h  right_in(R_q)=%h",
                 $time, dut.L_q, dut.R_q);
    end

    //stable output
    always @(posedge done) begin
        if (enc_dec)
            $display("Time %0t  [DONE][ENC] data_out=%h (valid=%0d)", $time, data_out, valid);
        else
            $display("Time %0t  [DONE][DEC] data_out=%h (valid=%0d)\n", $time, data_out, valid);
        
    end

    //handshake for enc/dec
    task run_op(input enc, input [63:0] din, output [63:0] dout);
    begin
        // make sure top lvl instance is idle before pulsing start
        wait(!busy);
        @(posedge clk);
        enc_dec = enc;
        data_in = din;
        start   = 1; @(posedge clk); start = 0; // full-cycle start pulse
        wait(done); @(posedge clk); // data_out stable
        dout = data_out;
    end
    endtask

    //Main test
    initial begin

        //times in ns
        $timeformat(-9, 0, " ns", 10);

        // Init
        clk = 0;
        rst_n = 0;
        start = 0;
        enc_dec = 1;
        data_in = 0;
        prev_state = 3'bxxx;

       
        $display("\nStarting DES Testbench");
        $display("\n");

        // Reset
        #10 rst_n = 1;
        #20;

        //ENCRYPT
        test_plain = 64'h0123_4567_89AB_CDEF;
        $display("***********ENCRYPTION TEST ***************");
        $display("Input plaintext: %h", test_plain);

        run_op(1'b1, test_plain, test_cipher);
        $display("Output ciphertext: %h\n", test_cipher);

        // Key dump from memory
        $display("Keys [0..7]:");
        for (i = 0; i < 8; i = i + 1) begin
            $display("\tK[%0d] = %012h", i, dut.U_storage.mem[i]);
        end
        $display("\n");

        //DECRYPT
        $display("************ DECRYPTION TEST *************");
        $display("Input ciphertext: %h", test_cipher);

        run_op(1'b0, test_cipher, test_roundtrip);
        $display("Output plaintext: %h", test_roundtrip);

        // PASS / FAIL
        if (test_roundtrip === test_plain)
            $display("\n*** PASS: Decryption matches original plaintext ***");
        else
            $display("\n*** FAIL: Expected %h, got %h ***", test_plain, test_roundtrip);

        $display("\n***************** Finished **************\n");

        #50;
        $stop;
    end
endmodule
