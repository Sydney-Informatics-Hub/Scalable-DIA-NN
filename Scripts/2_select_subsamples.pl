#!/usr/bin/env perl

use warnings;
use strict;

# Use default linux sort order to select N % of samples
# at regular intervals along the list
 
my $percent = $ARGV[0];
my $n = $ARGV[1]; 
my $list = $ARGV[2];

chomp $percent; 
chomp $n;
chomp $list; 

my $wiff_dir = 'Raw_data';    

my $select = sprintf("%.0f", ($n / $percent ) ); # round up 
my $div = $n / $select; 


open (L, ">$list") || die "$! write $list\n"; 
for ( my $i = 1; $i < $n; $i+=$div ) {
	my $t = sprintf("%.0f", $i );
	my $sample = `ls -1 $wiff_dir/*wiff | awk -v linenum=$t 'NR==linenum'`;
	chomp $sample; 
	print L "$sample\n";	
} close L; 

print "$select\n";  
