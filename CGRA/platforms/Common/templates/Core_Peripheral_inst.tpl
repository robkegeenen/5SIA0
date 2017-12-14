	<<UNIT_TYPE>>
	#(			
		.INTERFACE_WIDTH(INTERFACE_WIDTH),
		.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH)		
	)
	<<UNIT_NAME>>
	(
		.iClk(iClk),
		.iReset(iReset),
		
<<PERIPHERAL_CONNECTIONS>>

		.iReadRequest(wGen_Arb_ReadRequest[<<PERIPHERAL_NUMBER>>]),
		.iWriteRequest(wGen_Arb_WriteRequest[<<PERIPHERAL_NUMBER>>]),
		
		.iWriteAddress(wGen_Arb_WriteAddress[<<PERIPHERAL_NUMBER>>]),
		.iReadAddress(wGen_Arb_ReadAddress[<<PERIPHERAL_NUMBER>>]),
		.iWriteEnable(wGen_Arb_WriteEnable[<<PERIPHERAL_NUMBER>>]),
		.iWriteData(wGen_Arb_WriteData[<<PERIPHERAL_NUMBER>>]),
		.oReadData(wGen_Arb_ReadData[<<PERIPHERAL_NUMBER>>]),
		
		.oReadDataValid(wGen_Arb_ReadDataValid[<<PERIPHERAL_NUMBER>>]),
		.oWriteAccept(wGen_Arb_WriteAccept[<<PERIPHERAL_NUMBER>>])	
	);	