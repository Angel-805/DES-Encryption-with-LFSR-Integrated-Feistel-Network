`timescale 1ns/100ps
//pboxes added
module Key_gen #(parameter ROUNDS = 8)//internal rounds
(
    // key gen mode: generate key(1) reset to first key(0)
    input  wire       clk,rst,start,key_gen_mode,  
    output reg  [47:0] round_key,
    output reg        ready,done
);

// internal vars to keep track of rounds
reg [3:0] internal_round;    //max 16 rounds (0-7)
reg [47:0] keys [0:ROUNDS-1];        //creates a 2D array 48 bits wide, 8 levels deep
reg	init_done;         
reg [1:0] state;

//hardcoded base key and shift key
wire [55:0] base_key = 56'hB9D1CF565FB5A3; // 12 x 4 = 48 bits
wire [55:0] shift_key = 56'hA4CB3D492B86F0;
//----------------------------Pbox functions
function [47:0] pbox_1;
    input [47:0] in;
begin
    pbox_1 = {
        in[0],  in[47], in[23], in[15], in[31], in[7],   in[39], in[3],
        in[19], in[35], in[11], in[27], in[43], in[5],   in[21], in[37],
        in[13], in[29], in[45], in[1],  in[17], in[33],  in[9],  in[25],
        in[41], in[6],  in[22], in[38], in[14], in[30],  in[46], in[2],
        in[18], in[34], in[10], in[26], in[42], in[4],   in[20], in[36],
        in[12], in[28], in[44], in[8],  in[24], in[40],  in[16], in[32]
    };
end
endfunction

function [47:0] pbox_2;
    input [47:0] in;
begin
    pbox_2 = {
        in[12], in[5],  in[40], in[18], in[27], in[3],  in[36], in[45],
        in[8],  in[22], in[0],  in[39], in[17], in[9],  in[46], in[2],
        in[43], in[25], in[6],  in[32], in[15], in[38], in[20], in[47],
        in[7],  in[35], in[13], in[42], in[4],  in[29], in[16], in[11],
        in[44], in[21], in[26], in[33], in[31], in[19], in[23], in[10],
        in[30], in[37], in[14], in[24], in[1],  in[34], in[28], in[41]
    };
end
endfunction

//----------------------------------Run value through 2 pboxes
function [47:0] pbox_double;
    input [47:0] in;
    reg   [47:0] temp;
begin
    temp = pbox_1(in);
    pbox_double = pbox_2(temp);
end
endfunction

//----------------------------------initialize/reset
integer i,j;
always @(posedge clk or posedge rst) 
begin

if (rst) 
begin
	init_done	<= 0;
	internal_round	<= 0;
	
	for (i = 0; i < 8; i = i + 1) 
	begin
		keys[i] <= 48'h0;
	end
end
    
else if (!init_done) //
begin

//compute all keys in first cycle

	for(j= 0;j < ROUNDS; j = j +1)
	begin
	keys[j] <= base_key[55:8] ^ pbox_double((shift_key[55:8]) << j);
	end

	init_done <= 1;	
        $display("KeyGen: Initialized with derived keys from base key %h", base_key);
end
end

// --------------------------------State Machine
//output 1 key each cycle after start
always @(posedge clk or posedge rst) 
begin
    
if(rst) 
begin
	state          <= 0;
	round_key      <= 0;
	ready          <= 0;
	done           <= 0;
	internal_round <= 0;
end 
    
else 
begin

case (state)
            
0: begin // idle
	ready <= 0;
	done  <= 0;

	if (start && init_done)	//if start and keys are ready
	begin
                    
		if (!key_gen_mode)//key generate mode off
		begin
			internal_round <= 0;
		end
	
		state <= 1;
        end
end

1: 	//output new key each cycle
begin 
	round_key <= keys[internal_round];
	ready     <= 1;
	done      <= 1;
$display("KeyGen: Generated key[%0d] = %h", internal_round, keys[internal_round]);

	if (internal_round < 7) 
	begin
		internal_round <= internal_round + 1;
	end
                
	else 
	begin
		state <= 2; // finished all keys
	end
end

2: 	// done state
begin 
	ready <= 0;
	done  <= 1; //all keys are done
	//stay in idle until reset
	if (!start) state <= 0;
	end

	default: state <= 0;
	endcase
	end
end

endmodule
