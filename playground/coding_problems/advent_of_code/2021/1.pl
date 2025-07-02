use strict;
use warnings;

print "============= PART 1 =============\n";
part1();
print "============= PART 2 =============\n";
part2();

exit 0;

sub part1 {
    my $answer;
    open my $input, '<', './1.txt';

    my $previous_depth = <$input>;
    while(my $current_depth = <$input>) {
        ++$answer if $previous_depth < $current_depth;
        $previous_depth = $current_depth;
    }

    print "$answer measurements are larger than the previous measurement\n";
    close $input;
}


sub part2 {
    my ($previous_sum, $current_sum, $answer);
    open my $input, '<', './1.txt';

    my @input;
    push @input, $_ while <$input>;

    for(my $i = 0; $i < 3; ++$i) {
        $previous_sum += $input[$i];
    }

    my $index = 1;
    while ($input[$index + 2]) {
        for(my $i = $index; $i < $index + 3; ++$i) {
            $current_sum += $input[$i];
        }
        ++$index;
        ++$answer if $previous_sum < $current_sum;
        $previous_sum = $current_sum;
        $current_sum = 0;
    }

    print "$answer sums are larger than the previous sumn\n";
    close $input;
}

