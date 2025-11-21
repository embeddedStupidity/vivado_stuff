########################################################################################################
# scripts/create_project.tcl - Robust Vivado Tcl Script (Automatic Mode)
# 
# Author: Xavier Rosario
# E-Mail: nasaxman@gmail.com
#
# Description: This script assumes all custom IP sources will exist in a src/ directory,
# all constraints files exist in a xdc/ directory, and there is a create_bd.tcl script in a scripts/
# directory from within the FPGA repo's top-level. The script will generate a project, populate all
# sources, create a .bd file, create an HDL wrapper for said .bd file and set it to top.
#
# ######################################################################################################


# --- Dynamic Path Management --- 
set script_dir [file dirname [file normalize [info script]]] 
set project_root [file dirname $script_dir] 
set src_dir [file normalize "$project_root/src"] 
set xdc_dir [file normalize "$project_root/xdc"] 
cd $project_root 

# --- Define Generic Project Names (Agnostic defaults) --- 
set project_dir "project_1"
set project_name "project_1"
set part_name "xcvc1234-abcd5678-9EF-g-H" ;# !!! CHANGE THIS TO YOUR ACTUAL FPGA PART !!! 

# Clean previous runs (using defaults) 
file delete -force $project_dir 
file delete -force $src_dir/*.bd 

# --- Step 1: Create the Project --- 
puts "--- Step 1: Creating project ($project_name) with part $part_name ---" 
if {[catch {create_project $project_name ./$project_dir -part $part_name} err_msg]} { 
    error "COMMAND FAILED: create_project\nError: $err_msg" 
} 

# --- CRITICAL CHANGE: Use Automatic Compile Order Mode ---
# This is required to support 'create_bd_cell -type module -reference' commands.
puts "INFO: Switched project to AUTOMATIC Compile Order Mode for module reference compatibility."
if {[catch {set_property source_mgmt_mode All [current_project]} err_msg]} {
     error "COMMAND FAILED: set_property source_mgmt_mode All\nError: $err_msg"
}

# --- Step 2: Add Sources and Constraints (Vivado manages hierarchy now) ---

# Import all VHDL/Verilog sources found in the src directory
puts "--- Step 2:: Adding sources from $src_dir (Automatic mode handles hierarchy) ---"
# Using 'add_files' instead of 'import_files' for simplicity in automatic mode
if {[catch {add_files -fileset sources_1 [glob -nocomplain $src_dir/*.v* $src_dir/*.vhdl $src_dir/*.vhd]} err_msg]} {
     error "COMMAND FAILED: add_files (sources)\nError: $err_msg"
}

# Add constraints
puts "INFO: Adding constraints from $xdc_dir"
if {[catch {add_files -fileset constrs_1 [glob -nocomplain $xdc_dir/*.xdc]} err_msg]} {
     error "COMMAND FAILED: add_files (constraints)\nError: $err_msg"
}

# Vivado automatically updates the compile order after 'add_files'.

# --- Step 3: Source the create_bd.tcl script --- 
puts "--- Step 3: Sourcing create_bd.tcl to create Block Design structure ---" 
if {[catch {source [file normalize "$project_root/scripts/create_bd.tcl"]} result]} { 
    puts "Note: create_bd.tcl sourced with minor errors (expected), check previous errors." 
} 

set bd_name [get_property NAME [current_bd_design]]
puts "INFO: Determined BD name: $bd_name"

puts "INFO: Generating HDL wrapper for $bd_name"
if {[catch {make_wrapper -files [get_files *.bd] -top -force} err_msg]} {
    error "COMMAND FAILED: make_wrapper\nError: $err_msg"
}

# We dynamically search for the file using 'glob' in the exact output directory Vivado uses
# We use 'lappend' here to make sure we don't overwrite existing files in the sources_1 fileset.
set wrapper_dir [file normalize "$project_root/$project_dir/project_1.gen/sources_1/bd/$bd_name/hdl"]
set wrapper_file [glob -nocomplain $wrapper_dir/*_wrapper.v*]

if {[llength $wrapper_file] == 0} {
    error "CRITICAL ERROR: Failed to find generated wrapper file in $wrapper_dir"
}

puts "INFO: Adding generated wrapper file: $wrapper_file to project sources."
if {[catch {add_files -fileset sources_1 -norecurse $wrapper_file} err_msg]} {
     error "COMMAND FAILED: add_files (wrapper)\nError: $err_msg"
}

# 4. Update compile order twice (a common Vivado requirement when adding complex generated sources)
if {[catch {update_compile_order -fileset sources_1} err_msg]} {
    error "COMMAND FAILED: update_compile_order\nError: $err_msg"
}
if {[catch {update_compile_order -fileset sources_1} err_msg]} {
    error "COMMAND FAILED: update_compile_order\nError: $err_msg"
}

# --- Step 4: Finalization --- 
puts "--- Step 4: Finalizing project structure ---" 

# No explicit update_compile_order or make_wrapper needed.

# Project files are saved implicitly during commands and upon exit in batch mode. 
puts "--- Project creation complete. Project file: ${project_name}.xpr is ready. ---" 

# Exit Vivado batch session 
exit


