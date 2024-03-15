#!/usr/bin/env perl

# Calculate recommended averages for scan window, mass acc (MS2) and MS1 from subset of samples run at step 2


use warnings;
use strict;


my $cohort = '<cohort_name>';
my $n = <N>;
my $percent = <PC>;
 

my $logs = 'Logs/2_preliminary_analysis/';
my $temp = "$logs\/temp";
`grep "Averaged recommended" ${logs}/*.report.log.txt > $temp`; 

my ($mass_acc_sum, $ms1_acc_sum, $scan_window_sum) = ();
open (T, $temp) || die "$! $temp\n"; 
my $c = 0; 
while (my $line = <T>) {
	chomp $line; 
	$c++; 

	$line =~ m/Mass accuracy\D+([0-9]+)/i; # Extract the first number after 'Mass accuracy'
	my $mass_acc = $1; 
	$mass_acc_sum += $mass_acc;
		
		
	$line =~ m/MS1 accuracy\D+([0-9]+)/i; # Extract the first number after 'MS1 accuracy'
	my $ms1_acc = $1; 
	$ms1_acc_sum += $ms1_acc;
				
		
	$line =~ m/Scan window\D+([0-9]+)/i; # Extract the first number after 'Scan window'
	my $scan_window = $1; 
	$scan_window_sum += $scan_window;

} close T; 

`rm -rf $temp`;


my $mass_acc_av = sprintf("%.4f", ($mass_acc_sum / $c) );
my $ms1_acc_av = sprintf("%.4f", ($ms1_acc_sum / $c) );
my $scan_window_av = sprintf("%.0f", ($scan_window_sum / $c) );

print "Average recommended settings based on subsamples: \n\tMass accuracy: $mass_acc_av\n\tMS1 accuracy: $ms1_acc_av\n\tScan window: $scan_window_av\n"; 

my @scripts_to_update = ("Scripts/2_preliminary_analysis_make_input.sh", "Scripts/3_assemble_empirical_lib.pbs", "Scripts/4_individual_final_analysis_make_input.sh", "Scripts/5_summarise.pbs");

foreach my $script (@scripts_to_update) {
	`sed -i "s|^scan_window=.*|scan_window=${scan_window_av}|g" $script`;
	`sed -i "s|^mass_acc=.*|mass_acc=${mass_acc_av}|g" $script`;
	`sed -i "s|^ms1_acc=.*|ms1_acc=${ms1_acc_av}|g" $script`;
}

# Update log file names for step 2:
my $script_to_update = 'Scripts/2_preliminary_analysis_run_parallel.pbs';	
`sed -i "s|^#PBS -o.*|#PBS -o ./PBS_logs/step2_${cohort}_${n}s.o|g" $script_to_update`;
`sed -i "s|^#PBS -e.*|#PBS -e ./PBS_logs/step2_${cohort}_${n}s.e|g" $script_to_update`;

print "\nUpdating these as fixed parameters and running inputs generator for steps 2 and 4\n";
`bash Scripts/2_preliminary_analysis_make_input.sh`;
`bash Scripts/4_individual_final_analysis_make_input.sh`;

print "\n* Please update resources in Scripts/2_preliminary_analysis_run_parallel.pbs depending on your cohort size, then submit\n\n"; 






