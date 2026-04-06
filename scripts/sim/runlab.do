# Set the project root relative to this script (scripts/sim/)
set project_root [file normalize [file join [file dirname [info script]] ../..]]

# Set target module
if {$argc > 0} {
    set module $1
} else {
    set module DE1_SoC
}

# Create work library
vlib work

# Compile all SystemVerilog source files and testbenches
#     Packages first (if any), then source RTL, then testbenches.
#     NOTE: If you have incomplete files in these folders, they will be
#     picked up and will probably fail to compile. Delete any old/unused
#     files, or include only the specific files you need.
if {[glob -nocomplain ${project_root}/src/packages/*.sv] ne ""} {
    vlog "${project_root}/src/packages/*.sv"
}
vlog "${project_root}/src/*.sv"
vlog "${project_root}/tb/*.sv"

# Call vsim to invoke simulator
#     Make sure the last item on the line is the name of the testbench module
#     you want to execute.
vsim -voptargs="+acc" -t 1ps -lib work ${module}_testbench

# Source the wave do file
#     This should be the file that sets up the signal window for the module you
#     are testing.
do ${project_root}/scripts/waves/${module}_wave.do

# Make sure relevant windows are visible
view wave
view structure
view signals

# Run the simulation!
run -all

# vim: ft=tcl
