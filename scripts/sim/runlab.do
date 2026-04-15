# Derive project root from this script's absolute location.
# [file normalize [info script]] converts a relative [info script] result to
# an absolute path using the CWD at call-time, which is reliable in Questa
# whether the script is invoked as "do runlab.do" or "do scripts/sim/runlab.do".
set _self       [file normalize [info script]]
set project_root [file normalize [file join [file dirname $_self] ../..]]
puts "INFO runlab: project_root = $project_root"

# Usage: do runlab.do <module>
#   <module> must match both src/**/<module>.sv and tb/**/<module>_tb.sv
# NOTE: In Questa, do-script args arrive as ${1}, ${2}, ... not $argv/$argc.
#       $argv/$argc hold Questa's own launch flags (e.g. -gui) — do not use them.
if {[info exists 1] && ${1} ne ""} {
    set module ${1}
} else {
    puts "ERROR: No module specified. Usage: do runlab.do <module>"
    return
}

# Create work library
vlib work

# Compile packages first, then all RTL recursively, then all testbenches recursively.
# NOTE: Any .sv file found under src/ or tb/ will be compiled. Remove stale files
#       if they cause compile errors.
set pkg_files [glob -nocomplain -directory ${project_root}/src/packages "*.sv"]
if {$pkg_files ne ""} {
    vlog {*}$pkg_files
}

set src_files [glob -nocomplain -directory ${project_root}/src -type f -tails -- "**/*.sv"]
foreach f $src_files {
    vlog "${project_root}/src/${f}"
}

set tb_files [glob -nocomplain -directory ${project_root}/tb -type f -tails -- "**/*.sv"]
foreach f $tb_files {
    vlog "${project_root}/tb/${f}"
}

# Invoke simulator on <module>_tb; save WLF to scripts/waves/
set wlf_path "${project_root}/scripts/waves/${module}.wlf"
vsim -voptargs="+acc" -t 1ps -lib work -wlf $wlf_path ${module}_tb

# Source the wave do file if it exists
set wave_do "${project_root}/scripts/waves/${module}_wave.do"
puts "INFO runlab: wave_do = $wave_do  exists=[file exists $wave_do]"
if {[file exists $wave_do]} {
    do $wave_do
} else {
    add wave -r /*
}

# Make sure relevant windows are visible
view wave
view structure
view signals

# Run the simulation!
run -all

# vim: ft=tcl
