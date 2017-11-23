`include "config.vh"

module MUL
#
(
	//parameters that can be externally configured
	parameter I_DECODED_WIDTH = 16,
	parameter D_WIDTH = 8,
	
	parameter NUM_INPUTS = 4,
	parameter NUM_OUTPUTS = 2,
	
	parameter SRC_WIDTH = 2,
	parameter DEST_WIDTH = 1,
	
	parameter TEST_ID = "0"
)
(	
	//inputs and outputs
	input iClk,
	input iReset,
	
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled	
		//state chain	
		input iStateDataIn,
		output oStateDataOut,	
		input iStateShift,
		input iNewStateIn,
		input iOldStateOut,		
	`endif	
	
	input [NUM_INPUTS*D_WIDTH-1:0] iInputs,
	output [NUM_OUTPUTS*D_WIDTH-1:0] oOutputs,
	
	input [I_DECODED_WIDTH-1:0] iDecodedInstruction	
);

	//local parameters, these depend on the actual implementation of the module and therefore are not configurable
	//from outside the module.
	localparam TYPE_MUL 			= 2'b10;
	localparam TYPE_PASS			= 2'b00;
	
	localparam OP_MUL 				= 2'b00;
	localparam OP_MUL_SH8 			= 2'b01;
	localparam OP_MUL_SH16 			= 2'b10;
	localparam OP_MUL_SH24 			= 2'b11;
	
	localparam MUL_DECODED_WIDTH = 15;
	localparam CONFIG_WIDTH = 1;
		
	wire [D_WIDTH-1:0] wInputs [NUM_INPUTS -1:0];
		
	wire wIsSigned;
	wire wDummy0;
	wire wDummy1;
	wire wDummy2;
	wire wReadHigher;
	wire wDualOut;
	wire [1:0] wType;	
	wire [1:0] wOperation;
	wire wOutputWrite;
		
	wire [DEST_WIDTH-1:0] wDest;
	wire [SRC_WIDTH-1:0]  wSrcA; 
	wire [SRC_WIDTH-1:0]  wSrcB; 
	
	//assign decoded instruction input to the control wires
	assign {wOutputWrite, wDualOut, wReadHigher, wIsSigned, wDummy1, wDummy0, wType, wOperation, wDest, wSrcB, wSrcA} = iDecodedInstruction[MUL_DECODED_WIDTH-1:0];
		
	reg [CONFIG_WIDTH-1:0] rConfig; 
	reg [D_WIDTH-1:0] rOutput[NUM_OUTPUTS-1:0];
	reg [D_WIDTH-1:0] rMULHigher;
	
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
		//----------------------------------------
		// STATE SAVING
		//----------------------------------------		
		localparam STATE_LENGTH = D_WIDTH*NUM_OUTPUTS + D_WIDTH; //output registers + mul higher register
		reg [STATE_LENGTH-1:0] rState;			
		assign oStateDataOut = rState[0];				
		//----------------------------------------	
	`endif	
		
	//unpack inputs and pack outputs, required since verilog does not allow 'arrays' as inputs or outputs for modules
	genvar gConnectPorts;
	generate
		for (gConnectPorts=0; gConnectPorts < NUM_INPUTS; gConnectPorts = gConnectPorts + 1)
			begin : Inputs
				assign wInputs[gConnectPorts] = iInputs[(gConnectPorts+1)*D_WIDTH-1 : gConnectPorts*D_WIDTH];
			end
											
		for (gConnectPorts=0; gConnectPorts < NUM_OUTPUTS; gConnectPorts = gConnectPorts + 1)
			begin : Outputs				
				assign oOutputs[(gConnectPorts+1)*D_WIDTH-1 : gConnectPorts*D_WIDTH] = rOutput[gConnectPorts];				
			end			
	endgenerate
	
	//types:
	// 10 	MUL
	
	//Operations:
	// 00		MUL
	
	//input select muxes
	wire [D_WIDTH-1:0] wOperandA = wInputs[wSrcA];
	wire [D_WIDTH-1:0] wOperandB = wInputs[wSrcB];
	
	//sign extention (or not, depending on wIsSigned)
	wire signed [D_WIDTH:0] wOperandA_SE = (wIsSigned) ? {wOperandA[D_WIDTH-1],wOperandA} : {1'b0,wOperandA};
	wire signed [D_WIDTH:0] wOperandB_SE = (wIsSigned) ? {wOperandB[D_WIDTH-1],wOperandB} : {1'b0,wOperandB};
		
	//perform operations
	reg signed [D_WIDTH*2-1:0] wMULOut_tmp;	
	always @(wOperandA_SE or wOperandB_SE or wType)
	begin
		case (wType)
			TYPE_MUL  : //MUL			
				wMULOut_tmp = wOperandA_SE * wOperandB_SE;
			default:
				wMULOut_tmp = {(D_WIDTH){1'b0}};
		endcase
	end
	
	reg [(D_WIDTH*2)-1:0] wMULOut;
	//select result	
	always @(wOperation or wMULOut_tmp)
	begin
		case (wOperation)
			OP_MUL :
				wMULOut = wMULOut_tmp;
			OP_MUL_SH8 :
				wMULOut = {{8{wMULOut_tmp[(D_WIDTH*2)-1]}} , wMULOut_tmp[(D_WIDTH*2)-1:8]};				
			OP_MUL_SH16 :
				wMULOut = {{16{wMULOut_tmp[(D_WIDTH*2)-1]}} , wMULOut_tmp[(D_WIDTH*2)-1:16]};				
			OP_MUL_SH24 :
				wMULOut = {{24{wMULOut_tmp[(D_WIDTH*2)-1]}} , wMULOut_tmp[(D_WIDTH*2)-1:24]};
			default : 
				wMULOut = {(D_WIDTH-1){1'b0}};
		endcase
	end			
	
	integer rStateCopy;
	integer gCurrStateBit;
	
	always @(posedge iClk)
	begin		
		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
		if (!iNewStateIn)
			begin			
		`endif	
				if (wOutputWrite)			
					if (!wDualOut)
						begin
							rOutput[wDest] <= wMULOut[D_WIDTH-1:0];
							rMULHigher <= wMULOut[D_WIDTH*2-1:D_WIDTH];
						end
					else
						begin
							rOutput[wDest+1] <= wMULOut[D_WIDTH*2-1:D_WIDTH];
							rOutput[wDest+0] <= wMULOut[D_WIDTH-1:0];
						end
						
				if (wReadHigher)
					if (wOperation==2'b00)
						rOutput[wDest] <=rMULHigher;
					else begin
						rOutput[wDest] <=wInputs[wSrcA];
					end
		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled			
			end
		else
			begin				
				rMULHigher <= rState[D_WIDTH-1:0];
				
				for (rStateCopy =0; rStateCopy < NUM_OUTPUTS; rStateCopy = rStateCopy + 1)
					rOutput[rStateCopy] <= rState[(rStateCopy+1)*D_WIDTH+D_WIDTH-1 -:D_WIDTH ];
			end
			
		if (iOldStateOut)
			begin
				rState[D_WIDTH-1:0] <= rMULHigher;
				
				for (rStateCopy =0; rStateCopy < NUM_OUTPUTS; rStateCopy = rStateCopy + 1)
					rState[(rStateCopy+1)*D_WIDTH+D_WIDTH-1 -:D_WIDTH ] <= rOutput[rStateCopy];			
			end
		
		if (iStateShift)
			begin
				rState[STATE_LENGTH-1] <= iStateDataIn;
				
				for (gCurrStateBit=0; gCurrStateBit < STATE_LENGTH-1; gCurrStateBit = gCurrStateBit + 1)		
					rState[gCurrStateBit] <= rState[gCurrStateBit+1];
			end			
		`endif					
	end
	

	// FOR SIMULATION/UNIT TESTING ONLY, SHOULD NOT BE SYNTHESIZED --------------------------------------

	// cadence translate_off	
	// synthesis translate_off
	`ifdef DUMP_DEBUG_FILES
	integer f;
	integer x;
	
	initial begin
	  f = $fopen({"MUL_out_",TEST_ID,".txt"},"w");
		for (x=0; x < NUM_OUTPUTS; x = x + 1)
			$fwrite(f,"out_reg%1d\t",x);		
		$fwrite(f,"rMulHigher\t\twMULOut\n");	
	
	  @(negedge iReset); //Wait for reset to be released
	  
	  forever
	  begin
		  @(posedge iClk)
		  begin	
				for (x=0; x < NUM_OUTPUTS; x = x + 1)
					$fwrite(f,"%b\t", rOutput[x]);			 				
				$fwrite(f,"%b\t%b\n", rMULHigher ,wMULOut);
		  end
		  
		  
	  end

	  $fclose(f);  
	end
	`endif
	// synthesis translate_on	
	// cadence translate_on
	//	--------------------------------------------------------------------------------------------------

endmodule
