quit -sim
if [file exists work] {vdel -all}
vlib work
vmap work work

vlog pcie_tlp_if.sv
vlog pcie_endpoint.sv
vlog pcie_uvm_tb.sv

vsim -voptargs=+acc work.tb_top +UVM_TESTNAME=pcie_test
add wave -r sim:/tb_top/*
run -all