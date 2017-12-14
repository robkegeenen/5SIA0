`include "config.vh"

module ALU
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
	
	//config chain
	input iConfigEnable,
	input iConfigDataIn,
	output oConfigDataOut,
	
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled		
		//state chain	
		input iStateDataIn,
		output oStateDataOut,	
		input iStateShift,
		input iNewStateIn,
		input iOldStateOut,	
	`endif

	input iCarryIn,
	output oCarryOut,	
	
	input [NUM_INPUTS*D_WIDTH-1:0] iInputs,
	output [NUM_OUTPUTS*D_WIDTH-1:0] oOutputs,
	
	input [I_DECODED_WIDTH-1:0] iDecodedInstruction	
);

	function integer MAX;
		input signed [31:0] A;		
		input signed [31:0] B;		
		begin
			if (A > B)
				MAX = A;
			else
				MAX = B;
		end
	endfunction	
	
	function integer MIN;
		input [31:0] A;		
		input [31:0] B;		
		begin
			if (A < B)
				MIN = A;
			else
				MIN = B;
		end
	endfunction		

	//local parameters, these depend on the actual implementation of the module and therefore are not configurable
	//from outside the module.
	localparam TYPE_LOGIC 		= 2'b00;
	localparam TYPE_SHIFT 		= 2'b01;
	localparam TYPE_ALU 			= 2'b10;
	localparam TYPE_COMPARE 	= 2'b11;
	
	localparam OP_AND 			= 2'b00;
	localparam OP_OR 				= 2'b01;
	localparam OP_XOR 			= 2'b10;
	localparam OP_PASS			= 2'b11;	
	
	localparam OP_SL1 			= 2'b00;
	localparam OP_SL4				= 2'b01;
	localparam OP_SR1 			= 2'b10;
	localparam OP_SR4				= 2'b11;		
	
	localparam ALU_DECODED_WIDTH = 16;
	localparam CONFIG_WIDTH = 3;
	localparam CARRY_CHAIN_CONFIG_WIDTH = 2;
			
	wire [D_WIDTH-1:0] wInputs [NUM_INPUTS -1:0];
		
	wire wIsSignExtention;	
	wire wIsSigned;
	wire wIsCMOV;
	wire wInvert;
	wire wEQ_LT;	
	wire wShiftA_L;
	wire [1:0] wType;	
	wire [1:0] wALU_Operation;
	wire wOutputWrite;
		
	wire [DEST_WIDTH-1:0] wDest;
	wire [SRC_WIDTH-1:0]  wSrcA; 
	wire [SRC_WIDTH-1:0]  wSrcB; 	
	
	//assign decoded instruction input to the control wires
	assign {wIsSignExtention, wOutputWrite, wShiftA_L, wIsCMOV, wIsSigned, wInvert, wEQ_LT, wType, wALU_Operation, wDest, wSrcB, wSrcA} = iDecodedInstruction[ALU_DECODED_WIDTH-1:0];
	wire wExternalShift = wShiftA_L;
	
	reg [CONFIG_WIDTH-1:0] rConfig; 
	reg [D_WIDTH-1:0] rOutput[NUM_OUTPUTS-1:0];
	reg [D_WIDTH-1:0] wALUOut;
	wire [D_WIDTH-1:0] wALUOut_Buffered;

	wire wIsSubtract;
	wire [D_WIDTH:0] wAdderOut;
	wire wIsMultiGranular;

	wire [CARRY_CHAIN_CONFIG_WIDTH-1:0] wCarrySettings = rConfig[CONFIG_WIDTH-1:CONFIG_WIDTH-CARRY_CHAIN_CONFIG_WIDTH];
	reg wCarryIn; //will become wire
	reg wCarryOut; //will become wire	

	always @(wCarrySettings or iCarryIn or wIsSubtract or wAdderOut[D_WIDTH] or wIsMultiGranular)
	begin
		if (wCarrySettings == 2'b00 | wCarrySettings == 2'b01 | !wIsMultiGranular) //if it is not in a chain or the start of a chain			
			wCarryIn = wIsSubtract;
		else begin
			wCarryIn = iCarryIn;
		end

		if (wCarrySettings == 2'b00 | wCarrySettings == 2'b10 | !wIsMultiGranular) //if it is not in a chain or the end of a chain			
			wCarryOut = 1'b0;
		else begin
			wCarryOut = wAdderOut[D_WIDTH];
		end
	end

	assign oCarryOut = wCarryOut;

	DATA_Buffer #(.WIDTH(D_WIDTH)) buffer_alu(.iData(wALUOut), .oData(wALUOut_Buffered));
	
	//unpack inputs and pack outputs, required since verilog does not allow 'arrays' as inputs or outputs for modules
	genvar gConnectPorts;
	generate
		for (gConnectPorts=0; gConnectPorts < NUM_INPUTS; gConnectPorts = gConnectPorts + 1)
			begin : Inputs
				assign wInputs[gConnectPorts] = iInputs[(gConnectPorts+1)*D_WIDTH-1 : gConnectPorts*D_WIDTH];
			end
			
		assign oOutputs[D_WIDTH-1: 0] = (rConfig[0]) ? rOutput[0] : wALUOut_Buffered;
						
		for (gConnectPorts=1; gConnectPorts < NUM_OUTPUTS; gConnectPorts = gConnectPorts + 1)
			begin : Outputs				
				assign oOutputs[(gConnectPorts+1)*D_WIDTH-1 : gConnectPorts*D_WIDTH] = rOutput[gConnectPorts];				
			end			
	endgenerate
			
	//----------------------------------------
	//	SCAN CHAIN CONFIG CODE
	//----------------------------------------
			
	integer gCurrBit;
	always @(posedge iClk)
	begin
		if (iConfigEnable)
			begin
				rConfig[CONFIG_WIDTH-1] <= iConfigDataIn;
				
				for (gCurrBit=0; gCurrBit < CONFIG_WIDTH-1; gCurrBit = gCurrBit + 1)		
					rConfig[gCurrBit] <= rConfig[gCurrBit+1];
			end
	end
	assign oConfigDataOut = rConfig[0];
	
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled			
		//----------------------------------------
		// STATE SAVING
		//----------------------------------------
		
		localparam STATE_LENGTH = D_WIDTH*NUM_OUTPUTS + 1; //output registers + Flag register 
		reg [STATE_LENGTH-1:0] rState;			
		assign oStateDataOut = rState[0];	
	`endif
	
	//----------------------------------------		
	
	//types:
	// 00 Logic
	// 01 Shift
	// 10 ALU
	// 11 Compare
	
	//ALU operations
	
	//    00		01		10		11
	// 00 AND	SLL1	x		x
	// 01	OR		SLL4	x		x
	// 10	XOR	SR*1	!Sub	!Sub
	//	11 PASS	SR*4	Sub	Sub
	
	//compare wEQ_LT
	// 1 Equal
	// 0 Less than
	
	reg rFlag;
	reg [D_WIDTH-1:0] wOperandA_SE_DT; //will become wires
	reg [D_WIDTH-1:0] wOperandB_SE_DT;	
	
	//input select muxes
	wire [D_WIDTH-1:0] wOperandA = wInputs[wSrcA];
	wire [D_WIDTH-1:0] wOperandB = wInputs[wSrcB];
	
	wire [1:0] wSignExtendDataType =  wIsSignExtention ? {wShiftA_L, wEQ_LT} : 2'b00;
	
	//sign extention (or not, depending on wIsSigned)
	wire [D_WIDTH:0] wOperandA_SE = (wIsSigned) ? {wOperandA_SE_DT[D_WIDTH-1],wOperandA_SE_DT} : {1'b0,wOperandA_SE_DT};
	wire [D_WIDTH:0] wOperandB_SE_tmp = (wIsSigned) ? {wOperandB_SE_DT[D_WIDTH-1],wOperandB_SE_DT} : {1'b0,wOperandB_SE_DT};
	
	//determine subtract wire
	assign wIsSubtract = wType[1] & wALU_Operation[0] & wALU_Operation[1];
		
	//create nbitwise inverse 
	wire [D_WIDTH:0] wOperandB_SE_inv = ~wOperandB_SE_tmp;
	wire [D_WIDTH:0] wOperandB_SE = (wIsSubtract) ? wOperandB_SE_inv : wOperandB_SE_tmp;
	wire wFirstInChain = (wCarrySettings == 2'b00 | wCarrySettings == 2'b01 | !wIsMultiGranular);
	
	//perform Add/subtract operation
	assign wAdderOut = wOperandA_SE + wOperandB_SE + (wFirstInChain ? wIsSubtract : (wIsSubtract ? !wCarryIn : wCarryIn));

	assign wIsMultiGranular = (wSignExtendDataType==0) & wIsSignExtention & wIsSigned;

	always @(wOperandA[D_WIDTH-1:0] or wOperandB[D_WIDTH-1:0] or wSignExtendDataType)
	begin					
		if (wSignExtendDataType == 1 & D_WIDTH > 8)	
				begin
						wOperandA_SE_DT = {{(MAX(0,D_WIDTH-8)){wOperandA[MIN(D_WIDTH-1,7)]}}, wOperandA[MIN(D_WIDTH-1,7):0]};
						wOperandB_SE_DT = {{(MAX(0,D_WIDTH-8)){wOperandB[MIN(D_WIDTH-1,7)]}}, wOperandB[MIN(D_WIDTH-1,7):0]};
				end
		else if (wSignExtendDataType == 2 & D_WIDTH > 16)	
				begin
						wOperandA_SE_DT = {{(MAX(0,D_WIDTH-16)){wOperandA[MIN(D_WIDTH-1,15)]}}, wOperandA[MIN(D_WIDTH-1,15):0]};
						wOperandB_SE_DT = {{(MAX(0,D_WIDTH-16)){wOperandB[MIN(D_WIDTH-1,15)]}}, wOperandB[MIN(D_WIDTH-1,15):0]};
				end
		else if (wSignExtendDataType == 3 & D_WIDTH > 32)	
				begin
						wOperandA_SE_DT = {{(MAX(0,D_WIDTH-32)){wOperandA[MIN(D_WIDTH-1,31)]}}, wOperandA[MIN(D_WIDTH-1,31):0]};
						wOperandB_SE_DT = {{(MAX(0,D_WIDTH-32)){wOperandB[MIN(D_WIDTH-1,31)]}}, wOperandB[MIN(D_WIDTH-1,31):0]};
				end		
		else
				begin
						wOperandA_SE_DT = wOperandA;
						wOperandB_SE_DT = wOperandB;
				end							
	end
	
	//perform CMOV
	reg [D_WIDTH-1:0] wCMOVOut;
	always @(wOperandA_SE[D_WIDTH-1:0] or wOperandB_SE[D_WIDTH-1:0] or wIsCMOV or rFlag or wExternalShift or wType or wInputs[0][0])
	begin
		if (wIsCMOV & wType==2'b00)
			wCMOVOut = ((rFlag & !wExternalShift) | (wInputs[0][0] & wExternalShift)) ? wOperandB_SE[D_WIDTH-1:0] : wOperandA_SE[D_WIDTH-1:0];
		else
			wCMOVOut = wOperandA_SE[D_WIDTH-1:0];
	end
		
	//perform logic operations
	reg [D_WIDTH-1:0] wLogicOut_tmp;
	always @(wOperandA_SE[D_WIDTH-1:0] or wOperandB_SE[D_WIDTH-1:0] or wALU_Operation or wCMOVOut)
	begin
		case (wALU_Operation)
			OP_AND  : //AND			
				wLogicOut_tmp = wOperandA_SE[D_WIDTH-1:0] & wOperandB_SE[D_WIDTH-1:0];
			OP_OR   : //OR			
				wLogicOut_tmp = wOperandA_SE[D_WIDTH-1:0] | wOperandB_SE[D_WIDTH-1:0];
			OP_XOR  : //XOR			
				wLogicOut_tmp = wOperandA_SE[D_WIDTH-1:0] ^ wOperandB_SE[D_WIDTH-1:0];
			OP_PASS : //PASS			
				wLogicOut_tmp = wCMOVOut[D_WIDTH-1:0];
		endcase
	end
	
	//create and select negated or normal logic out
	wire [D_WIDTH-1:0] wLogicOut_inv = ~wLogicOut_tmp;
	wire [D_WIDTH-1:0] wLogicOut = (wInvert & !wIsSignExtention) ? wLogicOut_inv : wLogicOut_tmp;
	
	//perform shift operations
	reg [D_WIDTH-1:0] wShiftOut;
	always @(wOperandA_SE or wOperandB_SE or wALU_Operation or wShiftA_L or wCMOVOut)
	begin
		case (wALU_Operation)
			OP_SL1 : //SL*1			
				wShiftOut = {wCMOVOut[D_WIDTH-1-1:0],1'b0};
			OP_SL4 : //SL*4			
				wShiftOut = {wCMOVOut[D_WIDTH-4-1:0],4'b0};
			OP_SR1 : //SR*1			
				wShiftOut = {wShiftA_L ? wCMOVOut[D_WIDTH-1] : 1'b0, wCMOVOut[D_WIDTH-1:1]};
			OP_SR4 : //SR*4			
				wShiftOut = {wShiftA_L ? {4{wCMOVOut[D_WIDTH-1]}} : 4'b0, wCMOVOut[D_WIDTH-1:4]};
		endcase
	end	
	
	//determine if value if A == B or A < B
	wire wIsNotZero = (|wAdderOut[D_WIDTH-1:0]);	
	wire wIsZero = !wIsNotZero;
	wire wFlag_tmp = (wEQ_LT) ? wIsZero : wAdderOut[D_WIDTH];
	
	//possible inverting of condition
	wire wFlag_inv = !wFlag_tmp;	
	wire wFlag = (wInvert) ? wFlag_inv : wFlag_tmp;
	//wire [D_WIDTH-1:0] wFlag_extended = {D_WIDTH{wFlag}}; //copy flag D_WIDTH times
	wire [D_WIDTH-1:0] wFlag_extended = {{D_WIDTH-1{1'b0}},{wFlag}}; //pad flag with zeros
	
	//select result	
	always @(wType or wLogicOut or wShiftOut or wAdderOut or wFlag_extended)
	begin
		case (wType)
			TYPE_LOGIC : //Logic		
				wALUOut = wLogicOut;
			TYPE_SHIFT : //Shift		
				wALUOut = wShiftOut;
			TYPE_ALU : //ALU		
				wALUOut = wAdderOut[D_WIDTH-1:0];
			TYPE_COMPARE : //Compare		
				wALUOut = wFlag_extended;
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
				if (iReset)
					begin
						rFlag <= 1'b0;
					end
				else
					begin
					
						if (wType == TYPE_COMPARE)
							rFlag <= wFlag;
					
						if (wOutputWrite)			
							if (wDest != 0 | rConfig[0])
								rOutput[wDest] <= wALUOut;
					end
		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled			
			end
		else
			begin
				rFlag <= rState[0];
				
				for (rStateCopy =0; rStateCopy < NUM_OUTPUTS; rStateCopy = rStateCopy + 1)
					rOutput[rStateCopy] <= rState[(rStateCopy+1)*D_WIDTH -:D_WIDTH ];
			end
			
		if (iOldStateOut)
			begin
				rState[0] <= rFlag;
				
				for (rStateCopy =0; rStateCopy < NUM_OUTPUTS; rStateCopy = rStateCopy + 1)
					rState[(rStateCopy+1)*D_WIDTH -: D_WIDTH] <= rOutput[rStateCopy];				
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
	  f = $fopen({"ALU_out_",TEST_ID,".txt"},"w");
		for (x=0; x < NUM_OUTPUTS; x = x + 1)
			$fwrite(f,"rOutput%1d\t",x);		
		$fwrite(f,"ALU_out\t\tFlag\n");	
	
	  @(negedge iReset); //Wait for reset to be released
	  
	  forever
	  begin
		  @(posedge iClk)
		  begin	
				for (x=0; x < NUM_OUTPUTS; x = x + 1)
					$fwrite(f,"%b\t", rOutput[x]);			 				
				$fwrite(f,"%b\t%b\n", wALUOut, rFlag);
		  end
		  
		  
	  end

	  $fclose(f);  
	end
	`endif
	// synthesis translate_on	
	// cadence translate_on
	//	--------------------------------------------------------------------------------------------------
endmodule

