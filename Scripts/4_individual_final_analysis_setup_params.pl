#!/usr/bin/env perl

# Extract the recomemnded settings for scan window and mass accuracy from
# the log output of step 3
# Use these values as fixed params for step 4 and step 5
# Run this script after step 3 completes, to update the window and mass accuracy
# values in step 4 and step 5 scripts
# If this script is run, there is no need to run 4_individual_final_analysis_make_input.sh
# as it will be launched by this perl script
# If you want to use other values than what are suggested from step 3 log, do not run this,
# but instead run 4_individual_final_analysis_make_input.sh after first updating it with 
# your chosen ms1, ms2 and scan window values

# NB: this script prints out the recommendations line and extracted values
# If this output is incorrect - most likely because a) step 3 failed, or b) the version 
# of DiaNN used is different to the one tested with and the output line format
# has now changed - please update the syntax in this script to correctly obtain the values
# The script will tolerate changes to the order of the params as recorded in the log,
# is case insensitive, and will allow changes to white space, to insulate against small
# log format changes between DiaNN versions

# Since the I/O dirs, script names and log names are all hard coded, there is 
# NO NEED TO EDIT this script. Simply run it. It will update the rest of the workflow for
# you, make the inputs file for step 4 parallel job. You will only need to adjust the PBS 
# resource requets for step 4 as usual. 

use warnings;
use strict;

my ($mass_acc, $ms1_acc, $scan_window) = (); 

my $log = 'Logs/3_assemble_empirical_lib.log';
my $next_script = 'Scripts/4_individual_final_analysis_make_input.sh'; 
my $last_script = 'Scripts/5_summarise.pbs';

open (L, $log) || die "$! $log\n"; 
while (my $line = <L>) {
	chomp $line; 
	if ($line =~ m/Averaged recommended/) {
		print "Data line from $log\:\n$line\n\n"; 

		$line =~ m/Mass accuracy\D+([0-9]+)/i; # Extract the first number after 'Mass accuracy'
		$mass_acc = $1; 
		print "Recommended mass accuracy: $mass_acc\n"; 
		
		
		$line =~ m/MS1 accuracy\D+([0-9]+)/i; # Extract the first number after 'MS1 accuracy'
		$ms1_acc = $1; 
		print "Recommended MS1 accuracy: $ms1_acc\n"; 		
		
		
		$line =~ m/Scan window\D+([0-9]+)/i; # Extract the first number after 'Scan window'
		$scan_window = $1; 
		print "Recommended scan window: $scan_window\n\n"; 
		
		print "Updating these values within $next_script and $last_script...\n\n";
		`sed -i "s|^scan_window=.*|scan_window=${scan_window}|g" $next_script $last_script`; 
		`sed -i "s|^mass_acc=.*|mass_acc=${mass_acc}|g" $next_script $last_script`;
		`sed -i "s|^ms1_acc=.*|ms1_acc=${ms1_acc}|g" $next_script $last_script`;
		
		
		print "Running $next_script...\n\n"; 
		my $stdout=`bash $next_script`; 
		print "$stdout\n";  		
		
		close L; exit; 
	}
} 
