`include "config.vh"

module RF
#
(  //parameters that can be externally configured
	parameter I_DECODED_WIDTH = 16,
	parameter D_WIDTH = 8,
	
	parameter NUM_INPUTS = 4,
	parameter NUM_OUTPUTS = 2,
	
	parameter SRC_WIDTH = 2,
	parameter DEST_WIDTH = 1,
	
	parameter REG_ADDR_WIDTH = 4,
	
	parameter TEST_ID = "0"
)
(	//inputs and outputs
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
	localparam NUM_REGISTERS = 16;
	localparam ADDR_WIDTH_REGS = 4;
	
	localparam RF_DECODED_WIDTH = 14;
	
	wire [D_WIDTH-1:0] wInputs [NUM_INPUTS -1:0];
		
	wire wRegisterWriteImmediate;
	wire wRegisterReadImmediate;
	wire wRegisterRead;
	wire wRegisterWrite;
			
	wire [REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH-1:0] wRegFromOpcodeA;
	wire [REG_ADDR_WIDTH-1:0] wRegFromOpcodeB;
	wire [DEST_WIDTH-1:0] wDest;
	wire [SRC_WIDTH-1:0]  wSrcA; //datasrc (with the exception of registers)
	wire [SRC_WIDTH-1:0]  wSrcB; //addrsrc	
	
	wire [REG_ADDR_WIDTH-1:0] wRegisterAddr = {wRegFromOpcodeA,wDest,wSrcB};
	wire [REG_ADDR_WIDTH-1:0] wSrcSelected = (wRegisterRead & !wRegisterReadImmediate) ? wInputs[wSrcB][REG_ADDR_WIDTH-1:0] : (wRegisterWriteImmediate ? wRegFromOpcodeB[REG_ADDR_WIDTH-1:0] : wRegisterAddr[REG_ADDR_WIDTH-1:0]) ;
	
	//assign decoded instruction input to the control wires	
	assign {wRegFromOpcodeB, wRegFromOpcodeA, wRegisterRead, wRegisterReadImmediate, wRegisterWrite, wRegisterWriteImmediate, wDest, wSrcB, wSrcA} = iDecodedInstruction[RF_DECODED_WIDTH-1:0];
	
	reg [D_WIDTH-1:0] rRegisters [NUM_REGISTERS-1:0];
	wire [D_WIDTH-1:0] wOutput = rRegisters[wSrcSelected];
	
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
		//----------------------------------------
		// STATE SAVING
		//----------------------------------------	
		localparam STATE_LENGTH = D_WIDTH*NUM_REGISTERS; //registers * datawidth
		reg [STATE_LENGTH-1:0] rState;			
		assign oStateDataOut = rState[0];
		//-----------------------------------------
	`endif
		
	//unpack inputs and pack outputs, required since verilog does not allow 'arrays' as inputs or outputs for modules
	genvar gConnectPorts;
	generate
		for (gConnectPorts=0; gConnectPorts < NUM_INPUTS; gConnectPorts = gConnectPorts + 1)
			begin : Inputs
				assign wInputs[gConnectPorts] = iInputs[(gConnectPorts+1)*D_WIDTH-1 : gConnectPorts*D_WIDTH];
			end
			
		assign oOutputs[NUM_OUTPUTS*D_WIDTH-1 : (NUM_OUTPUTS-1)*D_WIDTH] = wOutput; //rOutput;
		
		for (gConnectPorts=0; gConnectPorts < NUM_OUTPUTS-1; gConnectPorts = gConnectPorts + 1)
			begin : Outputs				
				assign oOutputs[(gConnectPorts+1)*D_WIDTH-1 : gConnectPorts*D_WIDTH] = rRegisters[gConnectPorts];				
			end			
	endgenerate
	
	//structural description
	integer rStateCopy;
	integer gCurrStateBit;
	
	always @(posedge iClk)
	begin

			
		//if (wRegisterReadImmediate & !wRegisterWriteImmediate) 	//register immediate -> source register specified in opcode
		//	rOutput <= rRegisters[(wRegisterWriteImmediate) ? wRegFromOpcodeB : wRegisterAddr];
			
		//if (wRegisterReadImmediate & wRegisterWriteImmediate) 	//register immediate -> source register specified in opcode
		//	if (wRegisterAddr != wRegFromOpcodeB)
		//		rOutput <= rRegisters[(wRegisterWriteImmediate) ? wRegFromOpcodeB : wRegisterAddr];
		//	else
		//		rOutput <= wInputs[wSrcA]; //(reading the new value, just like in the memory)

		//if (wRegisterRead) //source register specified on input B
		//	rOutput <= rRegisters[wInputs[wSrcB]];


		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled						
		if (!iNewStateIn)
			begin			
		`endif
				if (wRegisterWrite) //target register specified on input B, data source is input A
					rRegisters[wInputs[wSrcB]] <= wInputs[wSrcA];
					
				if (wRegisterWriteImmediate)	//register immediate -> target register specified in opcode
					rRegisters[wRegisterAddr] <= wInputs[wSrcA];					
		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled								
			end
		else
			begin								
				for (rStateCopy =0; rStateCopy < NUM_REGISTERS; rStateCopy = rStateCopy + 1)
					rRegisters[rStateCopy] <= rState[(rStateCopy+1)*D_WIDTH-1 -:D_WIDTH ];
			end
			
		if (iOldStateOut)
			begin								
				for (rStateCopy =0; rStateCopy < NUM_REGISTERS; rStateCopy = rStateCopy + 1)
					rState[(rStateCopy+1)*D_WIDTH-1 -: D_WIDTH] <= rRegisters[rStateCopy];				
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
	  f = $fopen({"RF_out_",TEST_ID,".txt"},"w");
		for (x=0; x < NUM_OUTPUTS-1; x = x + 1)
			$fwrite(f,"pass_reg[%2d]\t",x);		
		$fwrite(f,"output\n");	
	
	  @(negedge iReset); //Wait for reset to be released
	  
	  forever
	  begin
		  @(posedge iClk)
		  begin	
				for (x=0; x < NUM_OUTPUTS; x = x + 1)
					$fwrite(f,"%b\t", rRegisters[x]);			 								
		  end
	  end

	  $fclose(f);  
	end
	`endif
	// synthesis translate_on	
	// cadence translate_on
	//	--------------------------------------------------------------------------------------------------		*/
endmodule

