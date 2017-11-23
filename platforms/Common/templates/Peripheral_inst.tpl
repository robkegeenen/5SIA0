	<<UNIT_TYPE>>
	#(			
		.INTERFACE_WIDTH(INTERFACE_WIDTH),
		.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),		
		.INTERFACE_BLOCK_WIDTH(INTERFACE_BLOCK_WIDTH),

		.TEST_ID (<<TEST_ID>>)	
	)
	<<UNIT_NAME>>
	(
		.iClk(iClk),
		.iReset(iReset),
		
<<PERIPHERAL_CONNECTIONS>>

		.iDTL_CommandValid(wDTL_<<PERIPHERAL_NAME>>_CommandValid),
		.oDTL_CommandAccept(wDTL_<<PERIPHERAL_NAME>>_CommandAccept),
		.iDTL_Address(wDTL_<<PERIPHERAL_NAME>>_Address),
		.iDTL_CommandReadWrite(wDTL_<<PERIPHERAL_NAME>>_CommandReadWrite),
		.iDTL_BlockSize(wDTL_<<PERIPHERAL_NAME>>_BlockSize),

		.oDTL_ReadValid(wDTL_<<PERIPHERAL_NAME>>_ReadValid),
		.oDTL_ReadLast(wDTL_<<PERIPHERAL_NAME>>_ReadLast),	
		.iDTL_ReadAccept(wDTL_<<PERIPHERAL_NAME>>_ReadAccept),
		.oDTL_ReadData(wDTL_<<PERIPHERAL_NAME>>_ReadData),
		
		.iDTL_WriteValid(wDTL_<<PERIPHERAL_NAME>>_WriteValid),		
		.iDTL_WriteLast(wDTL_<<PERIPHERAL_NAME>>_WriteLast),
		.oDTL_WriteAccept(wDTL_<<PERIPHERAL_NAME>>_WriteAccept),	
		.iDTL_WriteEnable(wDTL_<<PERIPHERAL_NAME>>_WriteEnable),	
		.iDTL_WriteData(wDTL_<<PERIPHERAL_NAME>>_WriteData)			
	);	