#!/usr/bin/perl

# with the initial version there is a problem
# with the last TAD if we open a TAD it will
# not be closed -> instead of printing when encounter start, print when encounter end

use strict;

MAIN : {
	my $prev_chr;  # mz: safer to check that a TAD do not span over chromo in case file is concatenated???
    my $prev_state = 0;
    my $prev_start;
    my $prev_end;
    
    my $chr;
    my $end;
    my $start;
    my $to_print_start;
    my $state = 0;
    
    my $first_TAD = 0;
    
    while (my $line = <>) {
		chomp $line;
		($prev_state, $prev_start, $prev_end, $prev_chr) = ($state, $start, $end, $chr);	
		($chr, $start, $end, $state) = split(/\t/,$line);
		
		if($first_TAD == 1) { # do not print the line if this is the first TAD of the chromo
			if ($state == 3 and $prev_state == 1) { 
				print $chr ."\t". $to_print_start ."\t".$prev_end."\n" if $prev_chr == $chr;
			}
		}

		# skip the first TAD until we encounter 1st TAD start 
		$first_TAD = 1 if $state == 3;
		next if $first_TAD == 0;
				
		#added mz: store position of the begin of new TAD
		$to_print_start = $start	if($state == 3 and $prev_state != $state);		

    } # end while-reading stdin
    
	# do not forget to print the last TAD if the last state == 1
    # ADDED 06.07 the if at the end of the statement because with very high resolution -> no domain at all
    # so nothing stored in $to_print_start and print only $end in the file
    if ($state == 1 and $prev_chr == $chr) {
		print $chr ."\t". $to_print_start ."\t".$end."\n" if $to_print_start;
    }
}


