/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module DTL_VGA
#(			
	parameter INTERFACE_WIDTH = 32,
	parameter INTERFACE_ADDR_WIDTH = 32,		
	parameter INTERFACE_BLOCK_WIDTH = 5,
	parameter INTERFACE_NUM_ENABLES = INTERFACE_WIDTH/8,
	
	parameter TEST_ID = "0"	
)
(
	input iClk,		
	input iReset,
	
	input iDTL_CommandValid,
	output oDTL_CommandAccept,
	input [INTERFACE_ADDR_WIDTH-1:0] iDTL_Address,
	input iDTL_CommandReadWrite,
	input [INTERFACE_BLOCK_WIDTH-1:0] iDTL_BlockSize,

	output oDTL_ReadValid,
	output oDTL_ReadLast,	
	input iDTL_ReadAccept,
	output [INTERFACE_WIDTH-1:0] oDTL_ReadData,
	
	input iDTL_WriteValid,		
	input iDTL_WriteLast,
	output oDTL_WriteAccept,	
	input [INTERFACE_NUM_ENABLES-1:0] iDTL_WriteEnable,	
	input [INTERFACE_WIDTH-1:0] iDTL_WriteData,
	
	input iVGAClk,	
	output [7:0] oVGA_R,
	output [7:0] oVGA_G,
	output [7:0] oVGA_B,	
	output oVGA_Clk,
	output oVGA_Sync,
	output oVGA_Blank,
	output oVGA_VS,
	output oVGA_HS
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
	
	localparam INTERFACE_BYTE_ENABLES_WIDTH = CLogB2(INTERFACE_NUM_ENABLES-1);	

	//parameters		
	localparam DATA_H = 640;
	localparam FP_H = 20;
	localparam BP_H = 44;
	localparam SYNCH_H = 96;
	
	localparam DATA_V = 480;
	localparam FP_V = 14;
	localparam BP_V = 28;
	localparam SYNCH_V = 3;
	
	localparam DISPLAY_RES_X = 320;
	localparam DISPLAY_RES_Y = 240;
	localparam DISPLAY_DEPTH = 8;
	localparam DISPLAY_VISIBLE_RANGE_OFFSET = 5;


	reg [9:0] rCounterH;
	reg [9:0] rCounterV;
	reg rSync_H;

	wire wWriteValid;
	wire [INTERFACE_WIDTH-1:0] wWriteData;
	wire [INTERFACE_ADDR_WIDTH-1:0] wWriteAddress;
	
	wire [31:0]	wReadAddressTemp = (rCounterH >> 1) + (((rCounterV - DISPLAY_VISIBLE_RANGE_OFFSET)>> 1) * DISPLAY_RES_X);
	wire [31:0]	wReadAddress = ($signed(wReadAddressTemp) >= 0) ? wReadAddressTemp : 32'b0;
	wire [7:0] wReadData;

	wire wClkVGA = iVGAClk;
		
	wire wSync_H = (rCounterH < DATA_H + FP_H) | (rCounterH > DATA_H + FP_H + SYNCH_H);
	wire wSync_V = (rCounterV < DATA_V + FP_V) | (rCounterV > DATA_V + FP_V + SYNCH_V);	
	
	wire wBlank_H = (rCounterH >= DATA_H);
	wire wBlank_V = (rCounterV >= DATA_V);

	assign oVGA_Clk = wClkVGA;	
	assign oVGA_Sync = 1'b1;
	assign oVGA_Blank = ~(wBlank_H | wBlank_V);	
	assign oVGA_HS = wSync_H;
	assign oVGA_VS = wSync_V;	
		
	assign oVGA_R = (wReadData != 0) ? 8'd255 : 8'd0;
	assign oVGA_G = (wReadData != 0) ? 8'd255 : 8'd0;
	assign oVGA_B = (wReadData != 0) ? 8'd255 : 8'd0;

	
	initial begin
		rCounterH = 10'd0;
		rCounterV = 10'd0;
	end

	DTL_SlaveInterface
	#(			
		.INTERFACE_WIDTH(INTERFACE_WIDTH),
		.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),		
		.INTERFACE_BLOCK_WIDTH(INTERFACE_BLOCK_WIDTH)		
	)
	DTL_VGA_SLAVE_inst
	(
		.iClk(iClk),
		.iReset(iReset),
		
		.iDTL_CommandValid(iDTL_CommandValid),
		.oDTL_CommandAccept(oDTL_CommandAccept),
		.iDTL_Address(iDTL_Address),
		.iDTL_CommandReadWrite(iDTL_CommandReadWrite),
		.iDTL_BlockSize(iDTL_BlockSize),

		.oDTL_ReadValid(oDTL_ReadValid),
		.oDTL_ReadLast(oDTL_ReadLast),	
		.iDTL_ReadAccept(iDTL_ReadAccept),
		.oDTL_ReadData(oDTL_ReadData),
		
		.iDTL_WriteValid(iDTL_WriteValid),		
		.iDTL_WriteLast(iDTL_WriteLast),
		.oDTL_WriteAccept(oDTL_WriteAccept),	
		.iDTL_WriteEnable(iDTL_WriteEnable),	
		.iDTL_WriteData(iDTL_WriteData),
		
		.oWriteValid(wWriteValid),
		.oWriteData(wWriteData),
		.oWriteEnable(),
		.oAddress(wWriteAddress),
		.iReadData()		
	);	
	
	always @(posedge wClkVGA)
	begin		
		if (rCounterH < DATA_H + FP_H + BP_H + SYNCH_H -1)
			begin
				rCounterH <= rCounterH + 1'd1;
			end
		else
			begin
				rCounterH <= 1'd0;
			end
			
		rSync_H <= wSync_H;
	end
	
	always @(negedge rSync_H)
	begin		
		if (rCounterV < DATA_V + FP_V + BP_V + SYNCH_V -1)
			begin
				rCounterV <= rCounterV + 1'd1;
			end
		else
			begin
				rCounterV <= 1'd0;
			end
	end		
	
	wire [INTERFACE_ADDR_WIDTH-1:0] wWriteAddressShifted = wWriteAddress>>INTERFACE_BYTE_ENABLES_WIDTH;
	
	// FOR SIMULATION/UNIT TESTING ONLY, SHOULD NOT BE SYNTHESIZED --------------------------------------
	
	// synthesis translate_off
	`define SIMULATION
	
	reg [DISPLAY_DEPTH-1:0] rFrameBuffer [DISPLAY_RES_X*DISPLAY_RES_Y-1:0];
	reg [DISPLAY_DEPTH-1:0] rOutBuffer;
	
	always @(posedge iClk)
	begin
		if (wWriteValid)
			rFrameBuffer[wWriteAddressShifted] <= wWriteData;
			
		rOutBuffer <= rFrameBuffer[wReadAddress];
	end
	
	assign wReadData = rOutBuffer;
	
	// synthesis translate_on	
	//	--------------------------------------------------------------------------------------------------				
	
	`ifndef SIMULATION
	RAM2P	RAM2P_inst (
		.data (wWriteData),
		.rdaddress (wReadAddress),
		.rdclock (wClkVGA),
		.wraddress (wWriteAddressShifted),
		.wrclock (iClk),
		.wren (wWriteValid),
		.q (wReadData)
		);	
	`endif
endmodule
