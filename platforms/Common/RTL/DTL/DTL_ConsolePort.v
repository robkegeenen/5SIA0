/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module DTL_Console
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
	
	output oWriteValid,
	output [INTERFACE_WIDTH-1:0] oWriteData,
	output [INTERFACE_NUM_ENABLES-1:0] oWriteEnable
		
);
	
	localparam FSM_WIDTH = 2;
	
	localparam FSM_STATE_RESET = 2'b00;
	localparam FSM_STATE_IDLE =  2'b01;
	localparam FSM_STATE_READ =  2'b10;
	localparam FSM_STATE_WRITE=  2'b11;
	
	reg [FSM_WIDTH-1:0] rState;
	reg [FSM_WIDTH-1:0] rState_nxt;
	
	reg rDTL_rd_last;
	reg rDTL_rd_last_nxt;
	
	reg rDTL_rd_valid;
	reg rDTL_rd_valid_nxt;
	
	reg rDTL_wr_accept;
	reg rDTL_wr_accept_nxt;
	
	reg rDTL_cmd_accept;
	
	reg [INTERFACE_NUM_ENABLES-1:0] rDTL_WriteEnable;
	
	reg [INTERFACE_ADDR_WIDTH-1:0] rAddr;
	reg [INTERFACE_ADDR_WIDTH-1:0] rAddr_nxt;
	
	reg [INTERFACE_BLOCK_WIDTH-1:0] rSize;
	reg [INTERFACE_BLOCK_WIDTH-1:0] rSize_nxt;
	
	assign oWriteValid = oDTL_WriteAccept;
	assign oWriteData = iDTL_WriteData;
	assign oWriteEnable = iDTL_WriteEnable;
	
	always @(posedge iClk)
	begin        
            rDTL_rd_last <= rDTL_rd_last_nxt;
            rAddr <= rAddr_nxt;				
            rSize <= rSize_nxt;
				
            if (iReset)
					begin
						 rState <= FSM_STATE_RESET;
						 rDTL_rd_valid  <= 0;
						 rDTL_wr_accept <= 0;						 
					 end
            else
					begin
						 rState <= rState_nxt;
						 rDTL_rd_valid  <= rDTL_rd_valid_nxt;
						 rDTL_wr_accept <= rDTL_wr_accept_nxt;
					end
        
	end
	
	always @(rState or iReset or rAddr or rSize or iDTL_Address or iDTL_BlockSize or iDTL_CommandValid or iDTL_CommandReadWrite or iDTL_WriteValid or iDTL_WriteEnable or iDTL_ReadAccept or rDTL_rd_last or rDTL_rd_valid or rDTL_wr_accept)
	begin
		case (rState)
			FSM_STATE_RESET:
				begin
					if (!iReset)
						rState_nxt <= FSM_STATE_IDLE;
					else
						rState_nxt <= FSM_STATE_RESET;
						
					rAddr_nxt <= 0;
					rSize_nxt <= 0;
					rDTL_rd_valid_nxt <= 1'b0;
					rDTL_wr_accept_nxt <= 1'b0;
					rDTL_rd_last_nxt <= 1'b1;	
					rDTL_cmd_accept <= 1'b0;
					rDTL_WriteEnable <= 0;
				end
			
			FSM_STATE_IDLE:
				begin
					rDTL_WriteEnable <= 0;
					rDTL_cmd_accept <= 1'b1;
					rAddr_nxt <= iDTL_Address[INTERFACE_ADDR_WIDTH-1:0];
					rSize_nxt <= iDTL_BlockSize[INTERFACE_BLOCK_WIDTH-1:0];
					               
               if(iDTL_CommandValid)
                   if (iDTL_CommandReadWrite) //read action
							begin
								rState_nxt <= FSM_STATE_READ;
								rDTL_rd_valid_nxt <= 1'b1;
								rDTL_wr_accept_nxt <= rDTL_wr_accept;
								
								if (iDTL_BlockSize == 0)
									rDTL_rd_last_nxt <= 1'b1;
								else
									rDTL_rd_last_nxt <= 1'b0;								
							end
                   else                      // write action
							begin
                       rState_nxt <= FSM_STATE_WRITE;
							  rDTL_rd_last_nxt <= rDTL_rd_last;
                       rDTL_wr_accept_nxt <= 1'b1;
							  rDTL_rd_valid_nxt <= rDTL_rd_valid;
							end
					else
						begin
							rState_nxt <= rState;
							rDTL_rd_valid_nxt <= rDTL_rd_valid;
							rDTL_wr_accept_nxt <= rDTL_wr_accept;
							rDTL_rd_last_nxt <= rDTL_rd_last;
						end
				end
				
			FSM_STATE_WRITE:
				begin
					 rDTL_cmd_accept <= 1'b0;
					 rDTL_rd_valid_nxt <= rDTL_rd_valid;
					 rDTL_rd_last_nxt <= rDTL_rd_last;
					 
					 if (iDTL_WriteValid) // handle the write
						begin
							 rDTL_WriteEnable <= iDTL_WriteEnable;
							 							 
							 if (rSize==0)
								begin
									rState_nxt <= FSM_STATE_IDLE;
									rDTL_wr_accept_nxt <= 1'b0;									
								end
							 else
								begin
									rState_nxt <= rState;
									rDTL_wr_accept_nxt <= rDTL_wr_accept;
								end
								
							 rSize_nxt <= rSize-1'd1;
							 rAddr_nxt <= rAddr+4; //apparently assuming a byte addressed memory
						end
					else
						begin
							rDTL_wr_accept_nxt <= rDTL_wr_accept;
							rState_nxt <= rState;
							rSize_nxt <= rSize;
							rAddr_nxt <= rAddr;
						end
				end
				
			FSM_STATE_READ:
				begin
				   
					if (iDTL_ReadAccept)		//handle the read
						if (rDTL_rd_last)						
							begin								
								rDTL_cmd_accept <= 1'b1;
								rAddr_nxt <= rAddr[INTERFACE_WIDTH-1:0];								
								rSize_nxt <= rSize[INTERFACE_BLOCK_WIDTH-1:0];
								
								if (iDTL_CommandValid) // There is a next action
									 if (iDTL_CommandReadWrite) // read action	
										begin
											rDTL_rd_valid_nxt <= rDTL_rd_valid;
											rDTL_wr_accept_nxt <= rDTL_wr_accept;
											
											// Remain in the read state, so rd_valid remains high.
											if (iDTL_BlockSize==0)
												begin
													rState_nxt <= rState;
													rDTL_rd_last_nxt <= 1'b1;
												end
											else
												begin
													rState_nxt <= rState;
													rDTL_rd_last_nxt <= 1'b0;										  
												end
										end
									 else            // write action
										begin
										  rState_nxt <= FSM_STATE_WRITE;
										  rDTL_rd_valid_nxt <= 1'b0;
										  rDTL_wr_accept_nxt <= 1'b1;
										  rDTL_rd_last_nxt <= rDTL_rd_last;
										end									 
								else
									 begin
									 	  rState_nxt <= FSM_STATE_IDLE;										  
										  rDTL_rd_valid_nxt <= 1'b0;
										  rDTL_wr_accept_nxt <= rDTL_wr_accept;
										  rDTL_rd_last_nxt <= rDTL_rd_last;
									 end
						  end
						else
							begin
								rState_nxt <= rState;
								rDTL_rd_valid_nxt <= rDTL_rd_valid;
								rDTL_wr_accept_nxt <= rDTL_wr_accept;
								
								rDTL_cmd_accept <= 1'b0;
								// Go to next word
								if (rSize == 1)
									 rDTL_rd_last_nxt <= 1'b1;
								else
									 rDTL_rd_last_nxt <= 1'b0;
								
								rSize_nxt <= rSize-1'd1;
								rAddr_nxt <= rAddr+4; //apparently assuming a byte addressed memory								
							end	
					else
						begin						
							rState_nxt <= rState;
							rAddr_nxt <= rAddr;
							rSize_nxt <= rSize;
							rDTL_rd_valid_nxt <= rDTL_rd_valid;
							rDTL_wr_accept_nxt <= rDTL_wr_accept;
							rDTL_rd_last_nxt <= rDTL_rd_last;
							rDTL_cmd_accept <= 1'b0;	
						end
			end
		endcase
	end
			
	assign oDTL_CommandAccept = rDTL_cmd_accept;
	assign oDTL_ReadValid = rDTL_rd_valid;
	assign oDTL_ReadLast = rDTL_rd_last;
	assign oDTL_ReadData = 0;
	
	assign oDTL_WriteAccept = rDTL_wr_accept;	
	
/*
	// FOR SIMULATION/UNIT TESTING ONLY, SHOULD NOT BE SYNTHESIZED --------------------------------------
	
	// synthesis translate_off
	integer f;
	integer x;
	
	initial begin
	  f = $fopen({"CONSOLE_",TEST_ID,".txt"},"w");
	  $fwrite(f,"output:\n");		
		
	  @(negedge iReset); //Wait for reset to be released
	  
	  forever
	  begin
		  @(posedge iClk)
		  begin		
				if (oWriteValid)
					begin
						$fwrite(f,"%x\n", oWriteData);			 								
						$display("CONSOLE: %x",oWriteData);
					end
		  end		
	  end

	  $fclose(f);  
	end
	
	// synthesis translate_on	
	//	--------------------------------------------------------------------------------------------------				
*/
endmodule
