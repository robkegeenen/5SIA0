/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module DTL_MasterInterface
#(
	parameter D_WIDTH = 32,	
	parameter ADDR_WIDTH = 32,
	parameter MEM_WIDTH = 32,
	
	parameter INTERFACE_WIDTH = 32,
	parameter INTERFACE_ADDR_WIDTH = 32,
	parameter INTERFACE_BLOCK_WIDTH = 5,
	
	parameter NUM_ENABLES = (MEM_WIDTH / 8)
)
(
	input iClk,
	input iReset,
	
	input iReadRequest,
	input iWriteRequest,
	
	input [ADDR_WIDTH-1:0] iWriteAddress,
	input [ADDR_WIDTH-1:0] iReadAddress,
	input [NUM_ENABLES-1:0] iWriteEnable,
	input [D_WIDTH-1:0] iWriteData,
	
	output oReadDataValid,
	output oWriteAccept,
	output [D_WIDTH-1:0] oReadData,
	
	input iDTL_CommandAccept,
	input iDTL_WriteAccept,
	input iDTL_ReadValid,
	input iDTL_ReadLast,
	input [INTERFACE_WIDTH-1:0] iDTL_ReadData,
		
	output oDTL_CommandValid,
	output oDTL_WriteValid,	
	output oDTL_CommandReadWrite,
	output [NUM_ENABLES-1:0] oDTL_WriteEnable,	
	output [INTERFACE_ADDR_WIDTH-1:0] oDTL_Address,
	output [INTERFACE_WIDTH-1:0] oDTL_WriteData,
	
	output [INTERFACE_BLOCK_WIDTH-1:0] oDTL_BlockSize,
	output oDTL_WriteLast,
	output oDTL_ReadAccept
);
			
	reg rPostponedRead;
	
	reg rCommandValid;	
	reg rWriteValid;	
	reg rWritePending;	
	reg rCommandReadWrite;	
	reg rReadDataValid;
	reg rWriteAccept;
			 
	reg [ADDR_WIDTH-1:0] rWriteAddress;
	reg [ADDR_WIDTH-1:0] rReadAddress;
	reg [NUM_ENABLES-1:0] rWriteEnable;	
	reg [D_WIDTH-1:0] rWriteData;	
	reg [D_WIDTH-1:0] rReadData;	

	reg rDTLBusy;

	wire wFirstCycle_Valid = iDTL_ReadValid; 

	assign oReadData = wFirstCycle_Valid ? iDTL_ReadData : rReadData ;
		
	assign oReadDataValid = iDTL_ReadValid;
	assign oWriteAccept = iDTL_WriteAccept; //rWriteAccept;
	
	assign oDTL_CommandValid = rCommandValid;
	assign oDTL_WriteValid = rWriteValid;			
	assign oDTL_CommandReadWrite = rCommandReadWrite;		
	assign oDTL_WriteEnable = rWriteEnable;
	assign oDTL_WriteData = rWriteData;
	assign oDTL_Address = rCommandReadWrite ? rReadAddress : rWriteAddress;
	
	assign oDTL_BlockSize={(INTERFACE_BLOCK_WIDTH){1'b0}};
	assign oDTL_WriteLast=1'b1;
	assign oDTL_ReadAccept=1'b1;

	always @(posedge iClk)
	begin
		if (iReset)			
			begin
				rReadDataValid <= 0;				
				rWriteAccept <= 0;
				rWriteEnable <= 0;
				rWriteAddress <= 0;
				rReadAddress <= 0;
								
				rPostponedRead <= 0;
				rCommandValid <= 0;
				rWriteValid <= 0;
				rCommandReadWrite <= 0;		
				rWritePending <= 0;
				rDTLBusy <= 0;
			end
		else			
			begin					
				//if read and write request occur at the same time
				//postpone the read request untill the write request is completed
				//this is required since DTL does not support both at the same time
				//and since we return the new value, we shuold perform the write first	
				if (!rDTLBusy)
					begin			
						if (iReadRequest & iWriteRequest)
							begin
								rWriteAddress <= iWriteAddress;
								rWriteData <= iWriteData;
								rWriteEnable <= iWriteEnable;
										
								//set the postponed flag and start a write operation
								rWritePending <= 1;						
								rReadAddress <= iReadAddress;
								rPostponedRead <= 1;
								rCommandValid <= 1;
								rWriteValid <= 1;
								rCommandReadWrite <= 0;
								rDTLBusy <= 1;
							end
						else
							begin
								if (iReadRequest)
									begin							
										rReadAddress <= iReadAddress;
										rPostponedRead <= 0;
										rCommandValid <= 1;
										rWriteValid <= 0;
										rCommandReadWrite <= 1;
										rDTLBusy <= 1;
									end
						
								if (iWriteRequest)
									begin								
										rWriteAddress <= iWriteAddress;
										rWriteData <= iWriteData;
										rWriteEnable <= iWriteEnable;
																		
										rWritePending <= 1;
										rPostponedRead <= 0;
										rCommandValid <= 1;
										rWriteValid <= 1;
										rCommandReadWrite <= 0;								
										rDTLBusy <= 1;
									end
							end
					end
											
				//DTL protocol handling
				if (rCommandValid & iDTL_CommandAccept)
					rCommandValid <= 0;
					
				if (rWriteValid & iDTL_WriteAccept)
					begin
						rWriteValid <= 0;									
										
						if (rPostponedRead) //if there was a read queued, execute it
							begin									
								rPostponedRead <= 0;
								rCommandValid <= 1;
								rWriteValid <= 0;
								rCommandReadWrite <= 1;							
							end
					end		

				rReadDataValid <= iDTL_ReadValid;	
				
				if (iDTL_ReadValid)
					rReadData <= iDTL_ReadData;

				if (iDTL_ReadValid | iDTL_WriteAccept)
					rDTLBusy <= 0;
				
				if (rWritePending)
					begin
						rWritePending <= 0;
						rWriteAccept <= iDTL_WriteAccept;
					end
				else
					rWriteAccept <= iDTL_WriteAccept;					
			end
	end
endmodule
