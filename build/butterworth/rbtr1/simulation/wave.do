onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /TB_CGRA_Top/dut/CGRA_Core_inst/CGRA_Compute_Wrapper_inst/CGRA_Compute_inst/imm_stor_inst/oImmediateOut
add wave -noupdate /TB_CGRA_Top/dut/CGRA_Core_inst/CGRA_Compute_Wrapper_inst/CGRA_Compute_inst/abu_stor_inst/oOutputs
add wave -noupdate /TB_CGRA_Top/dut/CGRA_Core_inst/CGRA_Compute_Wrapper_inst/CGRA_Compute_inst/rf_y_inst/oOutputs
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {30268 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {30227 ns} {30311 ns}
