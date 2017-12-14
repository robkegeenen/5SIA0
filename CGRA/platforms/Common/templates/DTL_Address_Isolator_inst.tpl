	DTL_Address_Isolator
	#
	(
		.INTERFACE_WIDTH(INTERFACE_WIDTH),
		.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),
		.INTERFACE_BLOCK_WIDTH(INTERFACE_BLOCK_WIDTH),

		.ADDRESS_RANGE_LOW(<<RANGE_LOW>>),
		.ADDRESS_RANGE_HIGH(<<RANGE_HIGH>>)	
	)
	<<UNIT_NAME>>
	(
		.iClk(iClk),
		.iReset(iReset),
		
		//input (SLAVE) DTL port
		.iDTL_IN_CommandValid(wDTL_ARB_CommandValid),
		.oDTL_IN_CommandAccept(wDTL_DMEM_<<PERIPHERAL_NAME>>_CommandAccept),
		.iDTL_IN_Address(wDTL_ARB_Address),
		.iDTL_IN_CommandReadWrite(wDTL_ARB_CommandReadWrite),
		.iDTL_IN_BlockSize(wDTL_ARB_BlockSize),

		.oDTL_IN_ReadValid(wDTL_DMEM_<<PERIPHERAL_NAME>>_ReadValid),
		.oDTL_IN_ReadLast(wDTL_DMEM_<<PERIPHERAL_NAME>>_ReadLast),	
		.iDTL_IN_ReadAccept(wDTL_ARB_ReadAccept),
		.oDTL_IN_ReadData(wDTL_DMEM_<<PERIPHERAL_NAME>>_ReadData),
		
		.iDTL_IN_WriteValid(wDTL_ARB_WriteValid),		
		.iDTL_IN_WriteLast(wDTL_ARB_WriteLast),
		.oDTL_IN_WriteAccept(wDTL_DMEM_<<PERIPHERAL_NAME>>_WriteAccept),
		.iDTL_IN_WriteEnable(wDTL_ARB_WriteEnable),	
		.iDTL_IN_WriteData(wDTL_ARB_WriteData),
		
		//output (MASTER) DTL port
		.oDTL_OUT_CommandValid(wDTL_<<PERIPHERAL_NAME>>_CommandValid),	
		.iDTL_OUT_CommandAccept(wDTL_<<PERIPHERAL_NAME>>_CommandAccept),
		.oDTL_OUT_Address(wDTL_<<PERIPHERAL_NAME>>_Address),
		.oDTL_OUT_CommandReadWrite(wDTL_<<PERIPHERAL_NAME>>_CommandReadWrite),
		.oDTL_OUT_BlockSize(wDTL_<<PERIPHERAL_NAME>>_BlockSize),
		
		.iDTL_OUT_ReadValid(wDTL_<<PERIPHERAL_NAME>>_ReadValid),
		.iDTL_OUT_ReadLast(wDTL_<<PERIPHERAL_NAME>>_ReadLast),
		.oDTL_OUT_ReadAccept(wDTL_<<PERIPHERAL_NAME>>_ReadAccept),
		.iDTL_OUT_ReadData(wDTL_<<PERIPHERAL_NAME>>_ReadData),
		
		.oDTL_OUT_WriteValid(wDTL_<<PERIPHERAL_NAME>>_WriteValid),	
		.oDTL_OUT_WriteLast(wDTL_<<PERIPHERAL_NAME>>_WriteLast),
		.iDTL_OUT_WriteAccept(wDTL_<<PERIPHERAL_NAME>>_WriteAccept),
		.oDTL_OUT_WriteEnable(wDTL_<<PERIPHERAL_NAME>>_WriteEnable),	
		.oDTL_OUT_WriteData(wDTL_<<PERIPHERAL_NAME>>_WriteData)
		
	);	