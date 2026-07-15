use strict;
use warnings;

for my $d (0..400) {
    printf "Decimal $d =";
    my $o = '';
    my $temp;
    while($d != 0) {
        $temp = $d;
        $d = int($d / 8);
        $o .= $temp % 8;
    }
    my @octal = reverse split //, $o;
    print " Octal: ", @octal, "\n";
}
