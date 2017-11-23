`include "config.vh"

module IU
#
(	//parameters that can be externally configured
	parameter I_IMM_WIDTH = 12,
	parameter D_WIDTH = 32,
	
	parameter INSERT_BUBBLE = 1,
	
	parameter TEST_ID = "0",
	parameter NUM_STALL_GROUPS = 1
)
(
	input iClk,
	input iReset,
	
	input [NUM_STALL_GROUPS-1:0] iStall,
	
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
		
	input  [I_IMM_WIDTH-1:0] iInstruction,
	output [D_WIDTH-1:0] 	 oImmediateOut	
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

	localparam EXTEND_REQUIRED = D_WIDTH > I_IMM_WIDTH-1;	
	localparam PART_SELECT = MIN(D_WIDTH, I_IMM_WIDTH-1);
	localparam STALL_GROUP_WIDTH = MAX(CLogB2(NUM_STALL_GROUPS-1),1);
	localparam CONFIG_WIDTH = 0+STALL_GROUP_WIDTH;

	integer iShift;

	reg  [I_IMM_WIDTH-1:0] rInstruction;
	wire [I_IMM_WIDTH-1:0] wInstruction = (INSERT_BUBBLE) ? rInstruction : iInstruction;
	wire wWriteEnable = wInstruction[I_IMM_WIDTH-1];
	wire [PART_SELECT-1:0] wDataIN = wInstruction[PART_SELECT-1:0];
	
	reg [D_WIDTH-1:0] rImmediateOut;
	reg rStall;
	reg [CONFIG_WIDTH-1:0] rConfig; 
	
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
		
		localparam STATE_LENGTH = I_IMM_WIDTH + D_WIDTH + 1; //output registers + Flag register 
		reg [STATE_LENGTH-1:0] rState;			
		assign oStateDataOut = rState[0];		
		//----------------------------------------	
	`endif
	
	wire [STALL_GROUP_WIDTH-1:0] wStallGroup = rConfig[CONFIG_WIDTH-1:CONFIG_WIDTH-STALL_GROUP_WIDTH];	
	
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
						//bubble insertion might be usefull to even out the delay differences for data availability
						//normal path is:
						//		IF (reg) -> ID (reg) -> FU (reg)			(3 stages)
						//but in the IU it would be:
						//		IF (reg) -> IU (reg)  						(2 stages)
						//with bubble it becomes:
						//		IF (reg) -> (reg) IU (reg)  				(3 stages)		
						if (INSERT_BUBBLE & !rStall)
							rInstruction <= iInstruction;
					
						if (wWriteEnable & !rStall)
							if (!EXTEND_REQUIRED)
								rImmediateOut[PART_SELECT-1:0] <= wDataIN;
							else
								begin
									for (iShift=I_IMM_WIDTH-1; iShift < D_WIDTH; iShift=iShift+1'd1)							
											rImmediateOut[iShift] <= rImmediateOut[iShift-(I_IMM_WIDTH-1)];
											
									rImmediateOut[PART_SELECT-1:0] <= wDataIN;
								end											
					end
		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled								
			end			
		else
			begin			
				rStall <= rState[0];				
								
				rInstruction <= rState[1+I_IMM_WIDTH-1:1];							
				rImmediateOut <= rState[1+I_IMM_WIDTH + D_WIDTH-1:1+D_WIDTH];
			end
			
		if (iOldStateOut)
			begin				
				rState[0] <= rStall;				
								
				rState[1+I_IMM_WIDTH-1:1] <= rInstruction;							
				rState[1+I_IMM_WIDTH + D_WIDTH-1:1+D_WIDTH] <= rImmediateOut;				
			end
		
		if (iStateShift)
			begin
				rState[STATE_LENGTH-1] <= iStateDataIn;
				
				for (gCurrStateBit=0; gCurrStateBit < STATE_LENGTH-1; gCurrStateBit = gCurrStateBit + 1)		
					rState[gCurrStateBit] <= rState[gCurrStateBit+1];
			end						
		`endif
	end
	
	assign oImmediateOut = rImmediateOut;


	// FOR SIMULATION/UNIT TESTING ONLY, SHOULD NOT BE SYNTHESIZED --------------------------------------

	// cadence translate_off	
	// synthesis translate_off
	`ifdef DUMP_DEBUG_FILES
	integer f;
	integer x;
	
	initial begin
	  f = $fopen({"IU_out_",TEST_ID,".txt"},"w");					
	  $fwrite(f,"output:\n");			 								
	
	  @(negedge iReset); //Wait for reset to be released
	  
	  forever
	  begin
		  @(posedge iClk)
				$fwrite(f,"%b\t%b\t%b\n", iInstruction, rStall, oImmediateOut);						 							
	  end

	  $fclose(f);  
	end
	`endif
	// synthesis translate_on	
	// cadence translate_on
	// -------------------------------------------------------------------------------------------------		

endmodule
