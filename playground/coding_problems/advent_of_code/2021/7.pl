use strict;
use warnings;
use bignum;

print "============= PART 1 =============\n";
part1();
print "============= PART 2 =============\n";
part2();

exit 0;

sub part1 {
    open my $input, '<', './7.txt';
    my @positions = split ',', <$input>;

    my $answer;
    my $min = 99999999999999;
    for my $position (@positions) {
        my $total = 0;
        for my $mdk (@positions) {
            $total += abs($position - $mdk);
        }
        if ($total < $min) {
            $answer = $position;
            $min = $total;
        }
    }
    print "the position is $answer and the fuel cost is $min\n";
}

sub part2 {
    open my $input, '<', './7.txt';
    my @positions = split ',', <$input>;

    my $answer;
    my $min = 99999999999999;
    for my $position (@positions) {
        my $total = 0;
        for my $pos (@positions) {
            my $steps = abs($position - $pos);
            my $cost = $steps * ($steps + 1) / 2;
            $total += $cost;
        }
        if ($total < $min) {
            $answer = $position;
            $min = $total;
        }
    }
    print "the position is $answer and the fuel cost is $min\n";
}
