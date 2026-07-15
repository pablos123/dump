use strict;
use warnings;

print "============= PART 1 =============\n";
part1();
print "============= PART 2 =============\n";
part2();

exit 0;

sub part1 {
    my ($horizontal, $depth);

    open my $input, '<', './2.txt';

    while (<$input>) {
        my @splited = split ' ', $_;
        $horizontal += $splited[1] if $splited[0] eq 'forward';
        $depth -= $splited[1] if $splited[0] eq 'up';
        $depth += $splited[1] if $splited[0] eq 'down';
    }

    print "we are currently in depth: $depth and horizontal: $horizontal\n";
    print $depth * $horizontal . " is the multiplication and the answer\n";

    close $input;
}


sub part2 {

    my ($horizontal, $depth);
    my $aim = 0;

    open my $input, '<', './2.txt';

    while (<$input>) {
        my @splited = split ' ', $_;
        if ($splited[0] eq 'forward') {
            $horizontal += $splited[1];
            $depth += $aim * $splited[1];
        }
        $aim -= $splited[1] if $splited[0] eq 'up';
        $aim += $splited[1] if $splited[0] eq 'down';
    }

    print "we are currently in depth: $depth and horizontal: $horizontal\n";
    print $depth * $horizontal . " is the multiplication and the answer\n";

    close $input;
}
