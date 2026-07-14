use strict;
use warnings;

# supports negatives lol


sub to_ten {
    my $n = shift;
    if ($n =~ /[^0-9A-Ya-y]/) {
        die 'not a base 35';
    }

    my ($count, $int, $d);
    my $is_n = 0;
    my @n = reverse(split //, $n);
    if($n[-1] eq '-') {
        $is_n = 1;
        pop(@n);
    }
    for my $letter (@n) {
        $letter = uc $letter;
        if(ord($letter) <= 57 and ord($letter) >= 48 ) {
            $d += ($letter*(35**$count++));
            next;
        }
        $int = ord($letter) - 65 + 10;
        $d += ($int*(35**$count++));
    }
    print "$ARGV[1] in base 10 is: -$d\n" and return  if $is_n;
    print "$ARGV[1] in base 10 is: $d\n" and return;
}



sub get_letter {
    my $n = shift;
    return $n if($n < 10);
    my $to_convert = $n - 10 + 65;
    return chr($to_convert);
}

sub to_35 {
    my $n = shift;
    if ($n =~ /[^0-9]/) {
        die 'not a base 10';
    }
    my $is_n = 0;
    if($n < 0) {
        $is_n = 1;
        $n = abs($n);
    }
    my $t = '';
    my $temp;
    while($n != 0) {
        $temp = $n;
        $n = int($n / 35);
        $t .= get_letter($temp % 35);
    }
    my @thirty = reverse split //, $t;

    print "$ARGV[1] in base 35 is: -", @thirty, "\n" and return  if $is_n;
    print "$ARGV[1] in base 35 is: ", @thirty, "\n" and return;
}


sub main {
    if ($ARGV[0] and $ARGV[1] and $ARGV[0] eq '-2dec') {
        to_ten($ARGV[1]);
    } elsif ($ARGV[0] and $ARGV[1] and $ARGV[0] eq '-2tf') {
        to_35($ARGV[1]);
    } else {
        print "Usage: <-2tf/-2dec> <number>"
    }
}


main();
