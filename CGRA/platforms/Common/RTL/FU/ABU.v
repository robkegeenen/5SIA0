`include "config.vh"

module ABU
#
(  //parameters that can be externally configured
	parameter I_DECODED_WIDTH = 16,
	parameter D_WIDTH = 16,
	parameter IM_ADDR_WIDTH = 16,
	
	parameter NUM_INPUTS = 4,
	parameter NUM_OUTPUTS = 2,
	
	parameter SRC_WIDTH = 2,
	parameter DEST_WIDTH = 1,
	
	parameter REG_ADDR_WIDTH = 4,
	
	parameter TEST_ID = "0",
	parameter NUM_STALL_GROUPS = 1
)
(	//inputs and outputs
	input iClk,
	input iReset,
	output oHalted,
	
	input [NUM_STALL_GROUPS-1:0] iStall,
	
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
		
	input [NUM_INPUTS*D_WIDTH-1:0] iInputs,
	output [NUM_OUTPUTS*D_WIDTH-1:0] oOutputs,
	
	input [I_DECODED_WIDTH-1:0] iDecodedInstruction	
);

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
	
	function integer MAX;
		input [31:0] A;		
		input [31:0] B;		
		begin
			if (A > B)
				MAX = A;
			else
				MAX = B;
		end
	endfunction		
	
	function integer CLogB2;
		input [31:0] Depth;
		integer i;
		begin
			i = Depth;		
			for(CLogB2 = 0; i > 0; CLogB2 = CLogB2 + 1)
				i = i >> 1;
		end
	endfunction		
	
	//local parameters, these depend on the actual implementation of the module and therefore are not configurable
	//from outside the module.
	localparam NUM_REGISTERS = 16;
	localparam ADDR_WIDTH_REGS = 4;
	localparam IMM_WIDTH = 6;
	
	localparam STALL_GROUP_WIDTH = MAX(CLogB2(NUM_STALL_GROUPS-1),1);
	localparam CONFIG_WIDTH = 1+STALL_GROUP_WIDTH;	
	
	localparam TYPE_ACCUMULATE = 1'b0;
	localparam TYPE_BRANCH = 1'b1;
	
	localparam ABU_DECODED_WIDTH = 14;
	
	localparam ADDR_REGS_REQ = (IM_ADDR_WIDTH >= D_WIDTH) ? 1: (D_WIDTH / IM_ADDR_WIDTH);
	
	//wires
	wire [D_WIDTH-1:0] wInputs [NUM_INPUTS -1:0];
	
	wire wAccumulate;
	wire wAccSigned_Unsigned;
	wire wBranchConditional;
	wire wJump;
	wire wAbsolute_Relative;
	wire wImmediate_Addressed;
	wire wRegisterWriteImmediate;
	wire wRegisterReadImmediate;
			
	wire [REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH-1:0] wRegFromOpcodeA;
	wire [DEST_WIDTH-1:0] wDest;		
	wire [SRC_WIDTH-1:0]  wSrcA; //datasrc
	wire [SRC_WIDTH-1:0]  wSrcB; //addrsrc	
	wire [IMM_WIDTH-1:0] wImmediate = {wAccumulate, wRegisterReadImmediate, wRegisterWriteImmediate, wDest, wSrcB}; // 4'b1101; //-3 
	wire wNotAccOrRegOperation = !(wAccumulate | wRegisterReadImmediate | wRegisterWriteImmediate);		
	
	//assign decoded instruction input to the control wires
	wire [REG_ADDR_WIDTH-1:0] wRegisterAddr = (wNotAccOrRegOperation) ? {REG_ADDR_WIDTH{1'b0}} : {wRegFromOpcodeA,wDest,wSrcB};	
	assign {wRegFromOpcodeA, wImmediate_Addressed, wAbsolute_Relative, wJump, wBranchConditional, wAccSigned_Unsigned, wAccumulate, wRegisterReadImmediate, wRegisterWriteImmediate, wDest, wSrcB, wSrcA} = iDecodedInstruction[ABU_DECODED_WIDTH-1:0];
		
	reg [CONFIG_WIDTH-1:0] rConfig; 
	reg [IM_ADDR_WIDTH-1:0] rRegisters [NUM_REGISTERS-1:0];
	reg [MAX(IM_ADDR_WIDTH,D_WIDTH)-1:0] rOutput;
	reg rHalted;
	reg rStall;
	
	wire [STALL_GROUP_WIDTH-1:0] wStallGroup = rConfig[CONFIG_WIDTH-1:CONFIG_WIDTH-STALL_GROUP_WIDTH];	
	
	assign oHalted = rHalted;

	//unpack inputs and pack outputs, required since verilog does not allow 'arrays' as inputs or outputs for modules
	genvar gConnectPorts;
	generate
		for (gConnectPorts=0; gConnectPorts < NUM_INPUTS; gConnectPorts = gConnectPorts + 1)
			begin : Inputs
				assign wInputs[gConnectPorts] = iInputs[(gConnectPorts+1)*D_WIDTH-1 : gConnectPorts*D_WIDTH];
			end

		if (D_WIDTH==8)
			begin
				assign oOutputs[(NUM_OUTPUTS-1)*D_WIDTH-1 : (NUM_OUTPUTS-2)*D_WIDTH] = (rConfig[0]) ? rRegisters[0][D_WIDTH-1:0] : rOutput[D_WIDTH-1:0];
				assign oOutputs[(NUM_OUTPUTS)*D_WIDTH-1 : (NUM_OUTPUTS-1)*D_WIDTH] = (rConfig[0]) ? rRegisters[0][2*D_WIDTH-1:D_WIDTH] : rOutput[2*D_WIDTH-1:D_WIDTH];
			end
		else
			begin
				if (D_WIDTH==32)
					assign oOutputs[(NUM_OUTPUTS-1)*D_WIDTH-1 : (NUM_OUTPUTS-2)*D_WIDTH] = (rConfig[0]) ? rOutput[D_WIDTH-1:0] : {rRegisters[NUM_OUTPUTS-2][MIN(D_WIDTH, IM_ADDR_WIDTH)-1:0],rRegisters[NUM_OUTPUTS-1][MIN(D_WIDTH, IM_ADDR_WIDTH)-1:0]};							
				else
					assign oOutputs[(NUM_OUTPUTS-1)*D_WIDTH-1 : (NUM_OUTPUTS-2)*D_WIDTH] = (rConfig[0]) ? rOutput[D_WIDTH-1:0] : {{(D_WIDTH-IM_ADDR_WIDTH){1'b0}},rRegisters[NUM_OUTPUTS-2][MIN(D_WIDTH, IM_ADDR_WIDTH)-1:0]};							
				assign oOutputs[(NUM_OUTPUTS)*D_WIDTH-1 : (NUM_OUTPUTS-1)*D_WIDTH] = (rConfig[0]) ? {{(D_WIDTH-IM_ADDR_WIDTH){1'b0}},rRegisters[0][IM_ADDR_WIDTH-1:0]} : rOutput[D_WIDTH-1:0];							
			end
			
		for (gConnectPorts=0; gConnectPorts < NUM_OUTPUTS-2; gConnectPorts = gConnectPorts + 1)
			begin : Outputs			
				if (D_WIDTH==32)
					begin	
						assign oOutputs[(gConnectPorts+1)*D_WIDTH-1 : gConnectPorts*D_WIDTH] = {rRegisters[gConnectPorts*2][MIN(D_WIDTH, IM_ADDR_WIDTH)-1:0],rRegisters[(gConnectPorts*2)+1][MIN(D_WIDTH, IM_ADDR_WIDTH)-1:0]};				
					end
				else
					begin
						assign oOutputs[(gConnectPorts+1)*D_WIDTH-1 : gConnectPorts*D_WIDTH] = rRegisters[gConnectPorts][MIN(D_WIDTH, IM_ADDR_WIDTH)-1:0];
					end
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
				//rConfig[CONFIG_WIDTH-1] <= iConfigDataIn;

				rConfig <= (rConfig >> 1) | (iConfigDataIn << (CONFIG_WIDTH-1));
				
				//for (gCurrBit=0; gCurrBit < CONFIG_WIDTH-1; gCurrBit = gCurrBit + 1)		
				//	rConfig[gCurrBit] <= rConfig[gCurrBit+1];
			end
	end
	
	assign oConfigDataOut = rConfig[0];
	
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled		
		//----------------------------------------
		// STATE SAVING
		//----------------------------------------
				
		localparam STATE_LENGTH = IM_ADDR_WIDTH*NUM_REGISTERS+MAX(IM_ADDR_WIDTH,D_WIDTH)+2;
		reg [STATE_LENGTH-1:0] rState;			
		assign oStateDataOut = rState[0];
		//-----------------------------------------		
	`endif
	
	wire wCondition = (wJump | (wInputs[wSrcA]!=0 & wBranchConditional));
	
	wire [IM_ADDR_WIDTH-1:0] wExtendedInput;
	
	generate
	 if (D_WIDTH == 8)
	   assign wExtendedInput = {rRegisters[NUM_REGISTERS-1][D_WIDTH-1:0], wInputs[wSrcB]};
	 else
		assign wExtendedInput = {{MAX((IM_ADDR_WIDTH-MIN(D_WIDTH,IM_ADDR_WIDTH)),1){wInputs[wSrcB][MIN(D_WIDTH,IM_ADDR_WIDTH)-1]}},wInputs[wSrcB][MIN(D_WIDTH,IM_ADDR_WIDTH)-1:0]};
	endgenerate
	
	reg [IM_ADDR_WIDTH-1:0] wPCIncrement;
	
	always @(wCondition or wAbsolute_Relative or wImmediate_Addressed or wImmediate or wExtendedInput or rStall)
	begin
		
		if (wCondition & !wAbsolute_Relative) 
			begin
				if (wImmediate_Addressed) 
					wPCIncrement = {{(IM_ADDR_WIDTH-IMM_WIDTH){wImmediate[IMM_WIDTH-1]}},wImmediate};
				else
					wPCIncrement = wExtendedInput;				
			end
		else	
			wPCIncrement = {{(IM_ADDR_WIDTH-1){1'b0}},1'b1};

	end
	
	wire [MAX(IM_ADDR_WIDTH,D_WIDTH)-1:0] wOperandA = (rConfig[0]) ? wPCIncrement : {{MAX((MAX(IM_ADDR_WIDTH,D_WIDTH)-D_WIDTH),1){wAccSigned_Unsigned}}, wInputs[wSrcA]};
	wire [MAX(IM_ADDR_WIDTH,D_WIDTH):0] wOperandA_SE = {wOperandA[IM_ADDR_WIDTH-1],wOperandA};
	
	wire [MAX(IM_ADDR_WIDTH,D_WIDTH)-1:0] wOperandB =(rConfig[0]) ? (rRegisters[0]) : ((ADDR_REGS_REQ!=1) ? {rRegisters[wRegisterAddr<<1],rRegisters[(wRegisterAddr<<1)+1]} : rRegisters[wRegisterAddr]);
	wire [MAX(IM_ADDR_WIDTH,D_WIDTH):0] wOperandB_SE = {wOperandB[IM_ADDR_WIDTH-1],wOperandB};
	
	wire [MAX(IM_ADDR_WIDTH,D_WIDTH):0] wAdderOut = wOperandA_SE + wOperandB_SE;
	
	wire [MAX(IM_ADDR_WIDTH,D_WIDTH)-1:0] wRegisterData = (!rConfig[0] & ADDR_REGS_REQ!=1) ? {rRegisters[wRegisterAddr<<1],rRegisters[(wRegisterAddr<<1)+1]} : rRegisters[wRegisterAddr];	
	
	integer iResetVar; //will be removed in synthesis
	
	//structural description	
	integer rStateCopy;
	integer gCurrStateBit;
	
	always @(posedge iClk)
	begin			

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled		
		if (!iNewStateIn)
			begin					
		`endif				
				if (!iReset)	
				begin
					rStall <= iStall[wStallGroup];

					if (wRegisterWriteImmediate & !wImmediate_Addressed)	//register immediate -> target register specified in opcode
						begin
							if (ADDR_REGS_REQ==1)
								rRegisters[wRegisterAddr] <= wInputs[wSrcA];
							else
								{rRegisters[wRegisterAddr<<1],rRegisters[(wRegisterAddr<<1)+1]} <= wInputs[wSrcA];
							end
						
					if (wRegisterReadImmediate &!wImmediate_Addressed) 	//register immediate -> source register specified in opcode			
							rOutput <= wRegisterData;								
						
					if (!rConfig[0])
						begin			
						
							rHalted <= 1'b1; //there should be at least one ABU in branch mode therefore an accumulator can be always 'halted'
							
							if (wAccumulate & !wImmediate_Addressed)
								if (ADDR_REGS_REQ==1) //8 and 16 bit version
									rRegisters[wRegisterAddr] <= wAdderOut[MAX(IM_ADDR_WIDTH,D_WIDTH)-1:0];
								else //only supported for 32 bit version
									{rRegisters[wRegisterAddr<<1],rRegisters[(wRegisterAddr<<1)+1]} <= wAdderOut[MAX(IM_ADDR_WIDTH,D_WIDTH)-1:0];
						end
					else
						begin
							if ( (wImmediate_Addressed & wImmediate == 0 & (!wBranchConditional | (wBranchConditional & wCondition))) | (wJump & !wImmediate_Addressed & !wBranchConditional & wAbsolute_Relative & wExtendedInput==0))
								rHalted <= 1'b1;
								
							if (rStall & !iStall[wStallGroup]) //just stopped stalling
								rRegisters[0] <= rRegisters[1];
							else
								if (!rHalted && !iStall[wStallGroup])
									if (!wAbsolute_Relative | (wBranchConditional & !wCondition))					
										rRegisters[0] <= wAdderOut[IM_ADDR_WIDTH-1:0];
									else
										if ((wBranchConditional & wCondition) | !wBranchConditional)
											rRegisters[0] <= (wImmediate_Addressed) ? {{(IM_ADDR_WIDTH-IMM_WIDTH){1'b0}},wImmediate} : wExtendedInput;	
							
							if (iStall[wStallGroup] & !rStall) //just stalled
								if (!wAbsolute_Relative)					
									rRegisters[1] <= wAdderOut[IM_ADDR_WIDTH-1:0];
								else
									if ((wBranchConditional & wCondition) | !wBranchConditional)
										rRegisters[1] <= (wImmediate_Addressed) ? {{(IM_ADDR_WIDTH-IMM_WIDTH){1'b0}},wImmediate} : wExtendedInput;		
									else
										rRegisters[1] <= wAdderOut[IM_ADDR_WIDTH-1:0];					
						end
				end
				
				if (iReset)		
					begin
						rHalted <= 1'b0;
						rStall <= 1'b0;
						
						for (iResetVar=1; iResetVar < NUM_REGISTERS; iResetVar = iResetVar+1)
							rRegisters[iResetVar] <= 0;

						if (!rConfig[0])					
							rRegisters[0] <= 0;
						else
							rRegisters[0] <= 1;
					end
		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled						
			end						
		else
			begin			
				rStall <= rState[0];
				rHalted <= rState[1];
								
				rOutput <= rState[2+MAX(IM_ADDR_WIDTH,D_WIDTH)-1:2];
							
				for (rStateCopy =0; rStateCopy < NUM_REGISTERS; rStateCopy = rStateCopy + 1)
					rRegisters[rStateCopy] <= rState[(rStateCopy+1)*IM_ADDR_WIDTH + MAX(IM_ADDR_WIDTH,D_WIDTH) -:IM_ADDR_WIDTH ];
			end
			
		if (iOldStateOut)
			begin				
			
				rState[0] <= rStall;
				rState[1] <= rHalted;
								
				rState[2+MAX(IM_ADDR_WIDTH,D_WIDTH)-1:2] <= rOutput;
				
				for (rStateCopy =0; rStateCopy < NUM_REGISTERS; rStateCopy = rStateCopy + 1)
					rState[(rStateCopy+1)*IM_ADDR_WIDTH + MAX(IM_ADDR_WIDTH,D_WIDTH) -:IM_ADDR_WIDTH ] <= rRegisters[rStateCopy];				
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

	integer f;
	integer x;

	`ifdef DUMP_DEBUG_FILES

	initial begin
	  f = $fopen({"ABU_out_",TEST_ID,".txt"},"w");
	  $fwrite(f,"output\n");		
			
	  @(negedge iReset); //Wait for reset to be released	  
	  forever
	  begin
		  @(posedge iClk)
		  begin	
				$fwrite(f,"%b\n", oOutputs);
		  end
	  end

	  $fclose(f);  
	end
	`endif

	reg rWasBranch;
	reg [IM_ADDR_WIDTH-1:0] rPrevAddr;
	reg [IM_ADDR_WIDTH-1:0] rStallAddr;
	reg [31:0] rStallCount;
	
	initial begin
	  rWasBranch = 0;
	  rStallCount = 0;

	  f = $fopen({"ABU_out_",TEST_ID,".txt"},"w");
	  			
	  @(negedge iReset); //Wait for reset to be released	  
	  forever
	  begin
		  @(posedge iClk)
		  begin	
			if (rConfig[0])
				begin
					if (wJump | wBranchConditional)
						begin
							rWasBranch <= 1;
							rPrevAddr <= rRegisters[0];
						end

					if (rWasBranch & !rStall)
						begin
							rWasBranch <= 0;
							$fwrite(f,"B\t%d\t%d\n",rPrevAddr, rRegisters[0]);	
						end


					if (iStall & !rStall)
						begin
							rStallAddr <= rRegisters[0];
							rStallCount <= rStallCount + 1'd1;	
						end

					if (rStall)											
						rStallCount <= rStallCount + 1'd1;							
						

					if (!iStall & rStall)						
						begin
							$fwrite(f,"S\t%d\t%d\n",rStallAddr, rStallCount);
							rStallCount <= 0;
						end
				end	
		  end
	  end

	  $fclose(f);  
	end	
	// synthesis translate_on	
	// cadence translate_on
	//	-------------------------------------------------------------------------------------------------- 
endmodule

