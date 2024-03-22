#!/usr/bin/env perl

# Filter unique genes matrix for missingness 

use warnings;
use strict; 

# Auto-updated by setup script:
my $n = <N>;
my $cohort = <cohort_name>;
my $missing = <value>;

# Hard-coded IO:
my $matrix = "5_summarise/$cohort\_${n}s_diann_report.unique_genes_matrix.tsv";
my $filtered = "5_summarise/$cohort\_${n}s_diann_report.filter-$missing\-percent.unique_genes_matrix.tsv";
my $discarded = "5_summarise/$cohort\_${n}s.filter-$missing\-percent.discarded_genes.txt";

# Do the filtering: 
my $pc = $missing/100; # min percent of samples with gene detected
my $min = sprintf("%.1f", ($n * $pc) ); 

print "Filtering $matrix for genes\nquantified in min ${missing}% of $n samples\n\n"; 

open (M, "$matrix") || die "$! $matrix\n";
open (F, ">$filtered") || die "$! write $filtered\n";
open (D, ">$discarded") || die "$! write $discarded\n";

chomp (my $header = <M>);
print F "$header\n";
print D "#GENE\t%_MISSING\n";

while (my $line = <M>) {
	chomp $line; 
	my (@cols) = split('\t', $line); 
	my $gene = $cols[0];
	my $length = @cols;
	if ($length < ($n + 1) ) {
		print "\tWARNING: blank at end of line (gene $gene) not being counted properly... ?\n"
	} 
	my $missing = 0; 
	for (my $i = 1; $i <= $length; $i++ ) {
		my $value = $cols[$i];
		if (! $value) {
			$missing++; 
		}
	}
	
	if ($missing > $min) {
		my $pc_missing = sprintf("%.2f", ($missing / $n * 100) );
		print D "$gene\t$pc_missing\n";
		print "\tDiscarding gene $gene - missing in $missing samples\n"; 
	}
	else {
		print F "$line\n"; 
	}  
 	
} close M; close F; close D; 

#if ($value =~m/[0-9]/)
