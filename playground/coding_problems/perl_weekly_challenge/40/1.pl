#we supposed that the arrays are defined and have the same length
use strict;
use warnings;

sub main {
    open my $fh, '<', './arrays';
    my @a;
    while(<$fh>) {
      push @a, eval $_;  
    }

    for (my $i = 0; $i < scalar @{$a[0]}; ++$i) {  
        print $_->[$i] . '   ' foreach @a;
        print "\n";
    }

    return 0;
}


main();
