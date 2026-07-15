#we supposed that the entries might not be in order, if the guest book is sorted
#we dont need to do the first loop
use strict;
use warnings;

sub main {
    open my $fh, '<', './guest_book' or die 1;
    my @entries;

    #parser
    while(<$fh>) {
        my $entry = [];
        $_ =~ /(\d{2}):(\d{2}).*(\d{2}):(\d{2})/;
        if(not $1 or not $2 or not $3 or not $4) {
            print "Bad input\n";
            die 1;
        }
        #matching groups are read-only
        my $in = $1 * 60 + $2; 
        my $out = $3 * 60 + $4;

        $entry->[0] = $in;
        $entry->[1] = $out; 
    
        push @entries, $entry;
    }

    #in case that the guest book is not sorted
    @entries = sort { $a->[0] <=> $b->[0] } @entries;

    my $total = $entries[0]->[1] - $entries[0]->[0];
    my $greater_out = $entries[0]->[1];
    foreach my $entry (@entries) {
        if($entry->[1] <= $greater_out) {
            next;
        }
        #check if the in time is greater than the last out time
        if($entry->[0] > $greater_out) {
            $total -= $entry->[0] - $greater_out;
        }
        $total += $entry->[1] - $greater_out;
        $greater_out = $entry->[1];
    }

    print $total . " minutes\n";
    return 0;
}

main();
