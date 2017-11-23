/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module DTL_Address_Isolator
#
(
	parameter INTERFACE_WIDTH = 32,
	parameter INTERFACE_ADDR_WIDTH = 32,
	parameter INTERFACE_BLOCK_WIDTH = 5,

	parameter ADDRESS_RANGE_LOW = 0,
	parameter ADDRESS_RANGE_HIGH = 4095,
	
	parameter INTERFACE_NUM_ENABLES = INTERFACE_WIDTH/8
)
(
	input iClk,
	input iReset,
	
	//input (SLAVE) DTL port
	input  										iDTL_IN_CommandValid,
	output 										oDTL_IN_CommandAccept,
	input  [INTERFACE_ADDR_WIDTH-1:0]  	iDTL_IN_Address,
	input  										iDTL_IN_CommandReadWrite,
	input  [INTERFACE_BLOCK_WIDTH-1:0] 	iDTL_IN_BlockSize,

	output 										oDTL_IN_ReadValid,
	output 										oDTL_IN_ReadLast,	
	input  										iDTL_IN_ReadAccept,
	output [INTERFACE_WIDTH-1:0] 			oDTL_IN_ReadData,
	
	input  										iDTL_IN_WriteValid,		
	input  										iDTL_IN_WriteLast,
	output 										oDTL_IN_WriteAccept,	
	input  [INTERFACE_NUM_ENABLES-1:0] 	iDTL_IN_WriteEnable,	
	input  [INTERFACE_WIDTH-1:0] 			iDTL_IN_WriteData,
	
	//output (MASTER) DTL port
	input 										iDTL_OUT_CommandAccept,
	input 										iDTL_OUT_WriteAccept,
	input 										iDTL_OUT_ReadValid,
	input 										iDTL_OUT_ReadLast,
	input [INTERFACE_WIDTH-1:0] 			iDTL_OUT_ReadData,
		
	output 										oDTL_OUT_CommandValid,
	output 										oDTL_OUT_WriteValid,	
	output 										oDTL_OUT_CommandReadWrite,
	output [INTERFACE_NUM_ENABLES-1:0] 	oDTL_OUT_WriteEnable,	
	output [INTERFACE_ADDR_WIDTH-1:0] 	oDTL_OUT_Address,
	output [INTERFACE_WIDTH-1:0] 			oDTL_OUT_WriteData,
	
	output [INTERFACE_BLOCK_WIDTH-1:0] 	oDTL_OUT_BlockSize,
	output 										oDTL_OUT_WriteLast,
	output 										oDTL_OUT_ReadAccept	
);
	wire wInRange = (iDTL_IN_Address >= ADDRESS_RANGE_LOW) & (iDTL_IN_Address <= ADDRESS_RANGE_HIGH);

	assign oDTL_IN_CommandAccept = iDTL_OUT_CommandAccept;
	assign oDTL_IN_ReadValid = iDTL_OUT_ReadValid;
	assign oDTL_IN_ReadData = iDTL_OUT_ReadData;
	assign oDTL_IN_ReadLast = iDTL_OUT_ReadLast;
	assign oDTL_IN_WriteAccept = iDTL_OUT_WriteAccept;
	
	assign oDTL_OUT_CommandValid = iDTL_IN_CommandValid & wInRange;
	assign oDTL_OUT_WriteValid = iDTL_IN_WriteValid & wInRange;
	assign oDTL_OUT_CommandReadWrite = iDTL_IN_CommandReadWrite;
	assign oDTL_OUT_WriteEnable = iDTL_IN_WriteEnable;
	assign oDTL_OUT_Address = iDTL_IN_Address-ADDRESS_RANGE_LOW;
	assign oDTL_OUT_WriteData = iDTL_IN_WriteData;
	
	assign oDTL_OUT_BlockSize = iDTL_IN_BlockSize;
	assign oDTL_OUT_WriteLast = iDTL_IN_WriteLast;
	assign oDTL_OUT_ReadAccept = iDTL_IN_ReadAccept;

endmodule
