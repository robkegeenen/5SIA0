module LOADER
#
(  //parameters that can be externally configured
	parameter INTERFACE_WIDTH = 32,
	parameter INTERFACE_ADDR_WIDTH = 32,
	
	parameter I_WIDTH = 15,
	parameter I_IMM_WIDTH = 33,
	parameter IM_ADDR_WIDTH = 16,	
	parameter IM_MEM_ADDR_WIDTH = 8,	
	
	parameter NUM_ID = 5,
	parameter NUM_IMM = 1	
)
(
	//inputs and outputs
	input iClk,
	input iReset,
	output oReset,
	output oConfigDone,

	//loader interface, goes via the top level module to the outside world
	input iLoaderWriteReq,
	output oLoaderReadReq,
	input [INTERFACE_WIDTH-1:0] iLoaderWriteData,
	output [INTERFACE_ADDR_WIDTH-1:0] oLoaderReadAddress,
	input [INTERFACE_WIDTH-1:0] iLoaderReadData,
	input iLoaderReadDataValid,
	
	//interface to the instruction memories (that are loaded by this module)
	output [NUM_IMM+NUM_ID-1:0] oIM_WriteEnable,
	output [IM_MEM_ADDR_WIDTH-1:0] oIM_WriteAddress,
	output [I_WIDTH-1:0] oIM_WriteData,
	output [I_IMM_WIDTH-1:0] oIM_WriteData_IMM,	
	
	//configuration scan-chain interface. For configurint the FUs and switchboxes
	output oConfigEnable,
	output oConfigDataIn		
);

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
	localparam INTERFACE_WIDTH_LOG2 = CLogB2(INTERFACE_WIDTH);
	
	localparam INDEX_WIDTH = 12;
	localparam INDEX_OFFSET = 16;
	
	localparam ALIGNMENT_WIDTH = 2;
	localparam ALIGNMENT_OFFSET = 30;
	
	localparam TYPE_WIDTH = 2;
	localparam TYPE_OFFSET = 28;
	
	localparam LENGTH_WIDTH = 16;
	localparam LENGTH_OFFSET = 0;
		
	localparam FSM_WIDTH = 4;
		
	localparam FSM_STATE_RESET = 4'b0000;
	localparam FSM_STATE_IDLE = 4'b0001;
	localparam FSM_STATE_GET_OFFSET = 4'b0010;
	localparam FSM_STATE_CONFIG_S0 = 4'b0011;
	localparam FSM_STATE_CONFIG_S1 = 4'b0100;	
	localparam FSM_STATE_CONFIG_S2 = 4'b0101;	
	localparam FSM_STATE_CONFIG_S3 = 4'b0110;		
	localparam FSM_STATE_HEADER_S0 = 4'b0111;
	localparam FSM_STATE_HEADER_S1 = 4'b1000;	
	localparam FSM_STATE_HEADER_S2 = 4'b1001;	
	localparam FSM_STATE_INSTR_S0 = 4'b1010;
	localparam FSM_STATE_INSTR_S1 = 4'b1011;	
	localparam FSM_STATE_INSTR_S2 = 4'b1100;	
	localparam FSM_STATE_INSTR_S3 = 4'b1101;	
	localparam FSM_STATE_NEXT_ID = 4'b1110;
	
	//registers
	reg [FSM_WIDTH-1:0] rState;
	reg [FSM_WIDTH-1:0] rNextState;
	
	reg [INTERFACE_WIDTH-1:0] rOffset;
	reg [INTERFACE_WIDTH-1:0] rWordCount;
	reg [INTERFACE_WIDTH-1:0] rConfigLength;
	reg [INTERFACE_WIDTH-1:0] rConfigData;
	reg [IM_MEM_ADDR_WIDTH-1:0] rInstructionAddress;
	reg [MAX(I_IMM_WIDTH,I_WIDTH)-1:0] rInstruction;
	
	reg [INDEX_WIDTH-1:0] rIndex;
	reg rConfigDataIn;
	
	reg [INTERFACE_WIDTH_LOG2-1:0] rCurrPart;	
	reg [INTERFACE_ADDR_WIDTH-1:0] rReadAddress;
	
	reg [ALIGNMENT_WIDTH-1:0] rAlignment;
	reg [TYPE_WIDTH-1:0] rType;
	
	reg rReadReq;
	reg rFirstWord;
	reg rWordDone;	
	reg rEnable;	
	reg rConfigDone;
	
	reg rConfigEnable;
		
	//wires
	wire wEnable = ((rState == FSM_STATE_INSTR_S3) & !rFirstWord & rAlignment!=0) | (rAlignment==0 & rEnable);
	
	//assignments
	genvar gConnectEnables;
	
	generate
		for (gConnectEnables=0; gConnectEnables < (NUM_ID+NUM_IMM); gConnectEnables=gConnectEnables+1)
			begin: Enables
				assign oIM_WriteEnable[gConnectEnables] = ((rIndex==gConnectEnables) & wEnable);
			end		
	endgenerate
	
	assign oIM_WriteAddress = rInstructionAddress-1'd1;
	assign oIM_WriteData = rInstruction[I_WIDTH-1:0];
	assign oIM_WriteData_IMM = rInstruction[I_IMM_WIDTH-1:0];
		
	assign oLoaderReadAddress = rReadAddress << 2;
	assign oLoaderReadReq = rReadReq;
	
	assign oReset = (rState != FSM_STATE_IDLE) | !oConfigDone | iReset;
	assign oConfigEnable=rConfigEnable;
	assign oConfigDataIn = rConfigDataIn;// rConfigData[rCurrPart];
	
	assign oConfigDone = rConfigDone;
		
	//behavioral
	always @(posedge iClk) begin
		if (!iReset)
			rState <= rNextState;
		else
			rState <= FSM_STATE_RESET;
	end

	//combinatorial part state machine
	always @(rState or iReset or iLoaderWriteReq or iLoaderReadDataValid or rConfigLength or rWordCount or rWordDone or rFirstWord or rType)
	begin
		case (rState)
			FSM_STATE_RESET:	begin	
										if (!iReset)
											rNextState <= FSM_STATE_IDLE;
										else
											rNextState <= rState;		
									end
									
			FSM_STATE_IDLE:	begin
										if (iLoaderWriteReq)
											rNextState <= FSM_STATE_GET_OFFSET;	
										else
											rNextState <= rState;																						
									end
									
			FSM_STATE_GET_OFFSET: begin
										if (!iLoaderWriteReq)
											rNextState <= FSM_STATE_CONFIG_S0;	
										else
											rNextState <= rState;															
									end
									
			//-------------------------- GET CONFIG ----------------------
			FSM_STATE_CONFIG_S0: begin										
										rNextState <= FSM_STATE_CONFIG_S1;
									end
									
			FSM_STATE_CONFIG_S1: begin
										if (iLoaderReadDataValid)
											rNextState <= FSM_STATE_CONFIG_S2;
										else
											rNextState <= rState;	
									end									
			FSM_STATE_CONFIG_S2: begin		
										rNextState <= FSM_STATE_CONFIG_S3;
									end
									
			FSM_STATE_CONFIG_S3: begin		
										if (!rWordDone)
											rNextState <= rState;
										else
											if (rWordCount != (rConfigLength+1) | rFirstWord) //was before: configlength==0
												rNextState <= FSM_STATE_CONFIG_S0;
											else
												rNextState <= FSM_STATE_HEADER_S0;
									end
									
			//-------------------------- GET HEADER ----------------------
			FSM_STATE_HEADER_S0: begin										
										rNextState <= FSM_STATE_HEADER_S1;
									end
									
			FSM_STATE_HEADER_S1: begin
										if (iLoaderReadDataValid)
											rNextState <= FSM_STATE_HEADER_S2;
										else
											rNextState <= rState;	
									end									
			FSM_STATE_HEADER_S2: begin		
										rNextState <= FSM_STATE_INSTR_S0;
									end			
		
			//-------------------------- GET INSTRUCTIONS ----------------------
			FSM_STATE_INSTR_S0: begin										
										rNextState <= FSM_STATE_INSTR_S1;
									end
									
			FSM_STATE_INSTR_S1: begin
										if (iLoaderReadDataValid)
											rNextState <= FSM_STATE_INSTR_S2;
										else
											rNextState <= rState;	
									end									
			FSM_STATE_INSTR_S2: begin		
										if (rType == {(TYPE_WIDTH){1'b1}})
											rNextState <= FSM_STATE_IDLE;
										else
											rNextState <= FSM_STATE_INSTR_S3;
									end
									
			FSM_STATE_INSTR_S3: begin		
										if (!rWordDone)
											rNextState <= rState;
										else
											if (rWordCount != (rConfigLength+1) | rFirstWord)
												rNextState <= FSM_STATE_INSTR_S0;
											else
												rNextState <= FSM_STATE_NEXT_ID;
									end		
									
			FSM_STATE_NEXT_ID: begin
										rNextState <= FSM_STATE_INSTR_S0;
									end	
									
			default:
				rNextState <= rState;
		endcase
	end
		
	//actions performed by state machine
	always @(posedge iClk) begin
	
		if (rState == FSM_STATE_RESET)
			begin
				rConfigDone <= 1'b0;				
			end
		
		if (rState == FSM_STATE_RESET | rState == FSM_STATE_IDLE)
			begin
				rOffset <= 'b0;
				rReadReq <= 1'b0;
				rFirstWord <= 1'b0;
				rWordCount <= 1'b0;
				rConfigLength <= 1'b0;				
				rConfigData <= 1'b0;		
				rConfigDataIn <= 1'b0;
				rCurrPart <= 1'b0;	
				rInstructionAddress <= 1'd1;		
				rEnable <= 1'b0;
				rType	<= 1'b0;
				rConfigEnable <= 1'b0;
			end
			
		if (rState == FSM_STATE_GET_OFFSET)			
			begin
				rOffset <= (iLoaderWriteData>>2);				
				rFirstWord <= 1'b1;
			end
		
		// ---------------------- CONFIG BITSTREAM ---------------------------
		if (rState == FSM_STATE_CONFIG_S0)
			begin
				rReadAddress <= rOffset + rWordCount;
				rReadReq <= 1'b1;					
			end
					
		if (rState == FSM_STATE_CONFIG_S1)		
			begin
				rReadReq <= 1'b0;												

				if (rFirstWord)			
					begin
						rConfigLength <= iLoaderReadData;							
						rWordDone <= 1'b1;
					end
				else
					begin
						rConfigData <= iLoaderReadData;	
						rWordDone <= 1'b0;
					end	
			end
		
		if (rState == FSM_STATE_CONFIG_S2)
			begin									
				rCurrPart <= 'd0;							
				rWordCount <= rWordCount + 1'd1;											
			end
			
		if (rState == FSM_STATE_CONFIG_S3)
			begin
				rFirstWord	<= 1'b0;
			
				if (!rFirstWord)										
					if (rCurrPart < INTERFACE_WIDTH)
						begin
							rCurrPart <= rCurrPart + 1'd1;	
							rConfigEnable <= 1'b1;
							rConfigDataIn <= rConfigData[rCurrPart];									
						end
					else
						begin
							rWordDone <= 1'b1;	
							rConfigEnable <= 1'b0;
						end
			end							
		
		//------------------------- HEADER ---------------------------
		
		if (rState == FSM_STATE_HEADER_S0)
			begin
				rReadAddress <= rOffset + rWordCount;				
				rReadReq <= 1'b1;					
			end
			
		if (rState == FSM_STATE_HEADER_S1)			
				rReadReq <= 1'b0;		

		if (rState == FSM_STATE_HEADER_S2)
			begin				
				rWordCount <= rWordCount + iLoaderReadData[LENGTH_WIDTH-1:LENGTH_OFFSET];			
				rFirstWord <= 1'b1;
				rInstructionAddress <= 1'd0;
				rCurrPart <= 1'd0;
			end			
			
		//------------------------- INSTRUCTIONS ---------------------------
		
		if (rState == FSM_STATE_INSTR_S0)
			begin
				rReadAddress <= rOffset + rWordCount;				
				rReadReq <= 1'b1;					
			end
			
		if (rState == FSM_STATE_INSTR_S1)			
				rReadReq <= 1'b0;		

		if (rState == FSM_STATE_INSTR_S2)
			begin								
				if (rFirstWord)
					begin
						rConfigLength <= rWordCount + iLoaderReadData[LENGTH_WIDTH+LENGTH_OFFSET-1:LENGTH_OFFSET];
						rAlignment <= iLoaderReadData[ALIGNMENT_WIDTH+ALIGNMENT_OFFSET-1:ALIGNMENT_OFFSET];
						rWordDone <= 1'b1;
						rIndex <= iLoaderReadData[INDEX_WIDTH+INDEX_OFFSET-1:INDEX_OFFSET];
						rType <= iLoaderReadData[TYPE_WIDTH+TYPE_OFFSET-1:TYPE_OFFSET];
						rCurrPart <= 'd0;	
						rEnable <= 1'b0;
						
						if (iLoaderReadData[TYPE_WIDTH+TYPE_OFFSET-1:TYPE_OFFSET] == {(TYPE_WIDTH){1'b1}})
							rConfigDone <= 1'b1;
					end
				else
					begin
						rConfigData <= iLoaderReadData;												
						
						if (rAlignment != 0)
							begin
								rCurrPart <= 'd0;	
								rWordDone <= 1'b0;
							end
						else
							rWordDone <= 1'b1;
					end
											
				rWordCount <= rWordCount + 1'd1;	
			end				
			
		if (rState == FSM_STATE_INSTR_S3)
			begin		
				
				if (!rFirstWord)
					begin
						if (rAlignment == 2)
							begin
								rInstruction <= rConfigData[(rAlignment-rCurrPart-1)*(INTERFACE_WIDTH/2)+:I_WIDTH];												
								
								if (!rWordDone)
									rInstructionAddress <= rInstructionAddress + 1'd1;	
								
								if (rCurrPart < rAlignment-1)											
									rCurrPart <= rCurrPart + 1'd1;																																
								else
									rWordDone <= 1'b1;
							end
							
						if (rAlignment == 1)
							begin
								rInstruction <= rConfigData[I_WIDTH-1:0];	
								rWordDone <= 1'b1;
								rInstructionAddress <= rInstructionAddress + 1'd1;	
							end
							
						if (rAlignment == 0)
							begin								
								if (rCurrPart )
									begin
										rCurrPart <= 1'b0;
										rInstructionAddress <= rInstructionAddress + 1'd1;	
										rEnable	<= 1'b1;
										rInstruction[INTERFACE_WIDTH-1:0] <= rConfigData[INTERFACE_WIDTH-1:0];
									end
								if (!rCurrPart) 
									begin
										rCurrPart <= 1'b1;													
										rInstruction[I_IMM_WIDTH-1:INTERFACE_WIDTH] <= rConfigData[I_IMM_WIDTH-INTERFACE_WIDTH-1:0];
									end									
							end	
					end
				else
					begin
						rFirstWord	<= 1'b0;			
					end
					
				if (rEnable)
					rEnable <= 1'b0;							
			end
			
		if (rState == FSM_STATE_NEXT_ID)
			begin				
				rFirstWord <= 1'b1;
				rInstructionAddress <= 1'd0;
				rCurrPart <= 1'd0;
			end
	end

endmodule
