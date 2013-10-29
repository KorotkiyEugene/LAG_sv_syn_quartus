transcript on
if ![file isdirectory verilog_libs] {
	file mkdir verilog_libs
}

vlib verilog_libs/altera_mf_ver
vmap altera_mf_ver ./verilog_libs/altera_mf_ver
vlog -vlog01compat -work altera_mf_ver {g:/quartus/quartus/eda/sim_lib/altera_mf.v}

vlib verilog_libs/altera_ver
vmap altera_ver ./verilog_libs/altera_ver
vlog -vlog01compat -work altera_ver {g:/quartus/quartus/eda/sim_lib/altera_primitives.v}

vlib verilog_libs/lpm_ver
vmap lpm_ver ./verilog_libs/lpm_ver
vlog -vlog01compat -work lpm_ver {g:/quartus/quartus/eda/sim_lib/220model.v}

vlib verilog_libs/sgate_ver
vmap sgate_ver ./verilog_libs/sgate_ver
vlog -vlog01compat -work sgate_ver {g:/quartus/quartus/eda/sim_lib/sgate.v}

vlib verilog_libs/stratixiv_hssi_ver
vmap stratixiv_hssi_ver ./verilog_libs/stratixiv_hssi_ver
vlog -vlog01compat -work stratixiv_hssi_ver {g:/quartus/quartus/eda/sim_lib/stratixiv_hssi_atoms.v}

vlib verilog_libs/stratixiv_pcie_hip_ver
vmap stratixiv_pcie_hip_ver ./verilog_libs/stratixiv_pcie_hip_ver
vlog -vlog01compat -work stratixiv_pcie_hip_ver {g:/quartus/quartus/eda/sim_lib/stratixiv_pcie_hip_atoms.v}

vlib verilog_libs/stratixiv_ver
vmap stratixiv_ver ./verilog_libs/stratixiv_ver
vlog -vlog01compat -work stratixiv_ver {g:/quartus/quartus/eda/sim_lib/stratixiv_atoms.v}

if {[file exists gate_work]} {
	vdel -lib gate_work -all
}
vlib gate_work
vmap work gate_work

vlog -vlog01compat -work work +incdir+. {LAG_2_900mv_0c_slow.vo}

vlog -sv -work work +incdir+G:/#Ucheba/#Disser/toGitHub/LAG_sv_syn_quartus {G:/#Ucheba/#Disser/toGitHub/LAG_sv_syn_quartus/LAG_functions.v}
vlog -sv -work work +incdir+G:/#Ucheba/#Disser/toGitHub/LAG_sv_syn_quartus {G:/#Ucheba/#Disser/toGitHub/LAG_sv_syn_quartus/LAG_random_traffic_source.v}
vlog -sv -work work +incdir+G:/#Ucheba/#Disser/toGitHub/LAG_sv_syn_quartus {G:/#Ucheba/#Disser/toGitHub/LAG_sv_syn_quartus/LAG_test_random.v}
vlog -sv -work work +incdir+G:/#Ucheba/#Disser/toGitHub/LAG_sv_syn_quartus {G:/#Ucheba/#Disser/toGitHub/LAG_sv_syn_quartus/LAG_traffic_sink.v}

vsim -t 1ps +transport_int_delays +transport_path_delays -L altera_mf_ver -L altera_ver -L lpm_ver -L sgate_ver -L stratixiv_hssi_ver -L stratixiv_pcie_hip_ver -L stratixiv_ver -L gate_work -L work -voptargs="+acc" LAG_test_random

add wave *
view structure
view signals
run -all
