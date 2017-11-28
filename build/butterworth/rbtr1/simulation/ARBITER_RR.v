/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module ARBITER_RR
#
(
	parameter NUM_PORTS = 1,
	parameter NUM_PORTS_WIDTH = 1
)
(
	input iClk,
	input iReset,
	
	input [NUM_PORTS-1:0] iRequest,
	output [NUM_PORTS-1:0] oGrant,
	output [NUM_PORTS_WIDTH-1:0] oSelected,
	
	output oActive,
	input  iPortBusy
);
	
	function [NUM_PORTS_WIDTH-1:0] findNext;
		input [NUM_PORTS-1:0] wRequest;	
		integer i;		
		begin
			findNext = 0;
			for (i=NUM_PORTS-1; i >= 0; i = i - 1)
				if (wRequest[i])
					findNext = i[NUM_PORTS_WIDTH-1:0];
		end
	endfunction
		
	reg [NUM_PORTS_WIDTH-1:0] rLast;
	reg rActive;
			
	wire [NUM_PORTS*2-1:0] wRequest_Concat = {iRequest, iRequest};
	wire [NUM_PORTS-1:0] wRequestHorizon = wRequest_Concat[(rLast+1'd1) +:NUM_PORTS];
	wire [NUM_PORTS_WIDTH:0] wNext_tmp = findNext(wRequestHorizon) + rLast + 1'd1;
	wire [NUM_PORTS_WIDTH-1:0] wNext = (wNext_tmp < NUM_PORTS) ? wNext_tmp[NUM_PORTS_WIDTH-1:0] : wNext_tmp - NUM_PORTS;
			
	always @(posedge iClk)
	begin
		if (iReset)
			begin
				rLast <= NUM_PORTS-1'd1;		
				rActive <= 1'b0;
			end
		else
			begin		
				if (!iPortBusy)
					begin
						if (iRequest[wNext])
							rLast <= wNext;					
							
						rActive <= iRequest[wNext];
					end
			end		
	end
	
	assign oGrant = rActive << rLast;
	assign oSelected = rLast;
	assign oActive = rActive;		 
endmodule
