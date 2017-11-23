	<<SWB_TYPE>>
	#
	(
		.WIDTH(<<WIDTH>>),
		.FU_INPUTS(<<NUM_INPUTS>>),
		.FU_OUTPUTS(<<NUM_OUTPUTS>>)
	)
	<<MODULE_NAME>>
	(
		<<WIRES>>

		<<CONTROL_WIRES>>
		//config chain
		.iClk(iClk),
		.iReset(iReset),
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(<<CONFIG_DATA_IN>>),
		.oConfigDataOut(<<CONFIG_DATA_OUT>>)
	);
