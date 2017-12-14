/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module STATE_CONTROLLER
#(
	parameter INTERFACE_WIDTH = 32,
	parameter INTERFACE_ADDR_WIDTH = 32,
	parameter STATE_BITS = 2853
)
(
	input iClk,
	input iReset,
	input iStall,
	
	//SC control signals
	input iStateReadRequest,
	input iStateWriteRequest,
	input iStateSwapRequest,	
	
	input iDisableShiftIn,
	input iDisableShiftOut,
	input iDisableExec,
	
	input [INTERFACE_WIDTH-1:0] iReadAddress,
	input [INTERFACE_WIDTH-1:0] iWriteAddress,
	
	//control signals for the state scan chain
	output oStateSwitchHalt,
	output oBusy,
		
	input iStateDataOut,
	output oStateDataIn,
	
	output oStateShift,
	output oStateNewIn,
	output oStateOldOut,	
	
	//memory control signals
	output oStateMemReadRequest,
	output oStateMemWriteRequest,
	output [INTERFACE_ADDR_WIDTH-1:0]  oStateMemAddress,
	output [INTERFACE_WIDTH-1:0] oStateMemWriteData,
	input [INTERFACE_WIDTH-1:0] iStateMemReadData,
	input iWriteAccept,
	input iReadValid
	
);	
	function integer CLogB2;
		input [31:0] Depth;
		integer i;
		begin
			i = Depth;		
			for(CLogB2 = 0; i > 0; CLogB2 = CLogB2 + 1)
				i = i >> 1;
		end
	endfunction	
	
	localparam INTERFACE_WIDTH_LOG2 = CLogB2(INTERFACE_WIDTH-1);
	localparam INTERFACE_WIDTH_ENABLES = CLogB2(INTERFACE_WIDTH/8-1);
	
	localparam FSM_WIDTH = 3;
	localparam FSM_STATE_RESET = 3'b000;
	localparam FSM_STATE_IDLE = 3'b001;	
	localparam FSM_STATE_SETSIG = 3'b010;
	localparam FSM_STATE_WAITMEM = 3'b011;
	localparam FSM_STATE_SHIFTIN = 3'b110;
	localparam FSM_STATE_SHIFTOUT = 3'b111;
	
	localparam TYPE_READ = 2'b00;
	localparam TYPE_WRITE = 2'b01;
	localparam TYPE_SWAP = 2'b10;
	localparam TYPE_INVALID = 2'b11;		

	localparam STATE_BITS_WIDTH = CLogB2(STATE_BITS);			

	reg rStateShift;
	reg rNewStateIn;
	reg rOldStateOut;
	
	reg rStateReadRequest;	
	reg rStateWriteRequest;
	reg rStateSwapRequest;

	reg rStateReadRequest_prev;	
	reg rStateWriteRequest_prev;
	reg rStateSwapRequest_prev;

	reg rDisableShiftIn;
	reg rDisableShiftOut;
	reg rDisableExec;
		
	reg [FSM_WIDTH-1:0] rState;
	reg [FSM_WIDTH-1:0] rStateNext;
	reg [1:0] rType;
	reg rSwitchHalt;
	reg [STATE_BITS_WIDTH-1:0] rShiftCount;
	reg [INTERFACE_WIDTH-1:0] rSubState;
	reg rFirstBit;
	reg rWriteRequest;
	reg rReadRequest;
	
	reg rWriteRequest_prev;
	reg rReadRequest_prev;
	
	reg rHaltShift;
	reg rShiftDone;
	reg rProcessRead;
			
	wire wWriteAccept = iWriteAccept;
	wire wReadValid = iReadValid;
	wire [INTERFACE_WIDTH-1:0] wDataIn;
	
	assign oStateDataIn = (rState == FSM_STATE_SHIFTIN) ? rSubState[0] : 1'b1;		
	assign oStateShift = rStateShift;
	assign oStateNewIn = rNewStateIn;
	assign oStateOldOut = rOldStateOut;
	assign oStateSwitchHalt = rSwitchHalt;
			
	always @(posedge iClk)
	begin
		if (!iReset)
			rState <= rStateNext;
		else			
			rState <= FSM_STATE_RESET;
	end
	
	always @(rState or iReset or rStateReadRequest or rStateWriteRequest or rStateSwapRequest or iStateReadRequest or iStateWriteRequest or iStateSwapRequest or rType or iStall or rShiftCount or rShiftDone or rDisableShiftIn or rDisableShiftOut or iDisableShiftIn or rStateReadRequest_prev or rStateWriteRequest_prev or rStateSwapRequest_prev)
	begin
		case (rState)
			FSM_STATE_RESET:
				begin
					if (!iReset)
						rStateNext <= FSM_STATE_IDLE;
					else
						rStateNext <= rState;						
				end
				
			FSM_STATE_IDLE:
				begin										
					if (!rStateReadRequest_prev & rStateReadRequest)
						rStateNext <= FSM_STATE_SETSIG;
					else if  ((!rStateWriteRequest_prev & rStateWriteRequest) | (!rStateSwapRequest_prev & rStateSwapRequest))
						if (!rDisableShiftIn & !iDisableShiftIn)
							rStateNext <= FSM_STATE_SHIFTIN;
						else
							rStateNext <= FSM_STATE_WAITMEM;
					else
						rStateNext <= rState;					
				end
				
			FSM_STATE_SETSIG:
				begin
					
					if (rType != TYPE_WRITE)
						if (!rDisableShiftOut)
							rStateNext <= FSM_STATE_SHIFTOUT;
						else
							rStateNext <= FSM_STATE_IDLE;						
					else
						rStateNext <= FSM_STATE_IDLE;
				end
			
			FSM_STATE_WAITMEM: //wait for all memory operations to complete if we are going to write a new state
				begin					
					if (|iStall == 1) 
						rStateNext <= rState;
					else						
						rStateNext <= FSM_STATE_SETSIG;					
				end

			FSM_STATE_SHIFTOUT:
				begin					
					if (rShiftDone)
						rStateNext <= FSM_STATE_IDLE;					
					else						
						rStateNext <= rState;
				end
							
			FSM_STATE_SHIFTIN:
				begin
					if (rShiftDone)
						rStateNext <= FSM_STATE_WAITMEM;
					else	
						rStateNext <= rState;
				end				
				
			default:
				begin
					rStateNext <= FSM_STATE_RESET;									
				end
		endcase
	end
	
	integer gInternalShift;
	
	always @(posedge iClk)
	begin
	
		rWriteRequest_prev <= rWriteRequest;
		rReadRequest_prev <= rReadRequest;
		
		if (rState == FSM_STATE_RESET)
			begin
				rSwitchHalt <= 0;
				rFirstBit <= 1;
				rShiftCount <= 0;
				rOldStateOut <= 0;
				rNewStateIn <= 0;		
				rStateShift <= 0;		
				rWriteRequest <= 0;
				rHaltShift <= 0;
				rShiftDone <= 0;
				rProcessRead <= 0;
				rReadRequest <= 0;
			end
			
		if (rState == FSM_STATE_IDLE)
			begin
				rSwitchHalt <= 0;
				rShiftCount <= 0;
				rFirstBit <= 1;
				rOldStateOut <= 0;
				rNewStateIn <= 0;		
				rStateShift <= 0;						
				rHaltShift <= 0;
				rShiftDone <= 0;
				rProcessRead <= 0;
				
				rStateReadRequest <= iStateReadRequest;
				rStateWriteRequest <= iStateWriteRequest;
				rStateSwapRequest <= iStateSwapRequest;

				rStateReadRequest_prev <= rStateReadRequest;
				rStateWriteRequest_prev <= rStateWriteRequest;
				rStateSwapRequest_prev <= rStateSwapRequest;
				
				rDisableShiftIn <= iDisableShiftIn;
				rDisableShiftOut <= iDisableShiftOut;
				rDisableExec <= iDisableExec;
			
				case ({rStateReadRequest, rStateWriteRequest, rStateSwapRequest})
					3'b100: rType <= TYPE_READ;
					3'b010: rType <= TYPE_WRITE;
					3'b001: rType <= TYPE_SWAP;
					default: rType <= TYPE_INVALID;											
				endcase
			end
			
		if (rState == FSM_STATE_SETSIG)
			begin				
				rShiftDone <= 0;
				rShiftCount <= 0;
				rFirstBit <= 1;
				rStateShift <= 0;	
				
				if (!rDisableExec)
					case (rType)
						TYPE_READ: rOldStateOut <= 1'b1;
						TYPE_WRITE: rNewStateIn <= 1'b1;
						TYPE_SWAP:
							begin
								rOldStateOut <= 1'b1;
								rNewStateIn <= 1'b1;
							end
					endcase
			end
		else
			begin
				rOldStateOut <= 1'b0;
				rNewStateIn <= 1'b0;
			end
			
		if (rState == FSM_STATE_SHIFTIN)	
			begin
			
				if (rShiftCount[INTERFACE_WIDTH_LOG2-1:0] == 0 & !rReadRequest & !rProcessRead)
					begin
						rReadRequest <= 1;
						rProcessRead <= 0;
					end					
				
				if (wReadValid)
					begin
						rReadRequest <= 0;						
						rSubState <= wDataIn;
						rProcessRead <= 1;
						rStateShift <= 1;
					end
				
				if (rShiftCount >= STATE_BITS-1)
					rStateShift <= 0;
				
				if (rShiftCount < STATE_BITS)
					begin										
							if (rProcessRead)
								begin
									if (rShiftCount[INTERFACE_WIDTH_LOG2-1:0] == INTERFACE_WIDTH-1)
										begin
											rProcessRead <=0;
											rStateShift <= 0;
										end
										
									rShiftCount <= rShiftCount + 1'd1;			
									
									for (gInternalShift=1; gInternalShift<INTERFACE_WIDTH; gInternalShift=gInternalShift+1)
										begin
											rSubState[gInternalShift-1] <= rSubState[gInternalShift];
										end
								end
					end										
				else
					begin						
						rShiftDone <= 1;
					end			
			end
			
		if (rState == FSM_STATE_SHIFTOUT)	
			begin
				rSwitchHalt <= 0;				
				rFirstBit <= 0;
				
				if (rShiftCount < STATE_BITS)
					begin
						if (!rWriteRequest & !rFirstBit)																						
								rShiftCount <= rShiftCount + 1'd1;															
					end
				else
					begin
						rStateShift <= 1'b0;						
						rWriteRequest <= 1'b1;					
						rHaltShift <= 1'b1;
					end
																	
				if (rShiftCount[INTERFACE_WIDTH_LOG2-1:0] == INTERFACE_WIDTH-2)
					begin
						rHaltShift <= 1;						
					end
					
				if (!rHaltShift)
					begin
						rStateShift <= 1;						
					end
				else
					rStateShift <= 0;
					
				rWriteRequest <= rHaltShift;
					
				if (!rWriteRequest)
					begin						
						rSubState[rShiftCount[INTERFACE_WIDTH_LOG2-1:0]] <= iStateDataOut ;						
					end				
					
			end
			
		if (rState == FSM_STATE_WAITMEM)
			begin
				rSwitchHalt <= 1;
			end
	
		if (wWriteAccept)
			begin
				rSubState <= 32'b1;
				rWriteRequest <= 0;
				rHaltShift <= 0;
				rStateShift <= 1;		
				
				if (rShiftCount == STATE_BITS)
					rShiftDone <= 1;
			end			
	end
	
	assign oStateMemWriteData= rSubState;
	assign oStateMemAddress = {(rShiftCount[STATE_BITS_WIDTH-1:5]-(rReadRequest ? 0: 1)+(rShiftCount == STATE_BITS) + (rReadRequest ? iWriteAddress: iReadAddress)), {(INTERFACE_WIDTH_ENABLES){1'b0}}};	
	assign wDataIn = iStateMemReadData;
	assign oStateMemReadRequest = rReadRequest & !rReadRequest_prev;
	assign oStateMemWriteRequest = rWriteRequest & !rWriteRequest_prev;
	assign oBusy = (rState != FSM_STATE_IDLE);
		
endmodule
