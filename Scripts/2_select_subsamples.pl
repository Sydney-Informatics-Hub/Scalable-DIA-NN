#!/usr/bin/env perl

use warnings;
use strict;

# Use default linux sort order to select N % of samples
# at regular intervals along the list
 
my $percent = $ARGV[0];
my $n = $ARGV[1]; 
my $list = $ARGV[2];
my $dia_suffix = $ARGV[3];

chomp $percent; 
chomp $n;
chomp $list;    

my $select = sprintf("%.0f", ($n / $percent ) ); # round up 
my $div = $n / $select; 


open (L, ">$list") || die "$! write $list\n"; 
for ( my $i = 1; $i < $n; $i+=$div ) {
	my $t = sprintf("%.0f", $i );
	my $sample = `ls -1 Raw_data/*${dia_suffix} | awk -v linenum=$t 'NR==linenum'`;
	chomp $sample; 
	print L "$sample\n";	
} close L; 

print "$select\n";  
