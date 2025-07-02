use strict;
use warnings;

print "============= PART 1 =============\n";
part1();
print "============= PART 2 =============\n";
part2();

exit 0;

sub part1 {
    open my $input, '<', '5.txt';

    my @coordinates;
    while(<$input>) {
        my @coordinate = split '->', $_;
        push @coordinates, \@coordinate;
    }

    my @values;
    for (0 .. 1000) {
        my @arr = (0) x 1000;
        $values[$_] = \@arr;
    }

    for my $coordinate (@coordinates) {
        my ($x1, $y1) = split ',', $coordinate->[0];
        my ($x2, $y2) = split ',', $coordinate->[1];

        if ($x1 == $x2) {
            my $i = $y1 > $y2 ? $y2 : $y1;
            for my $j ($i .. $i + abs($y1 - $y2)) {
                $values[$x1][$j]++;
            }
        } elsif ($y1 == $y2) {
            my $i = $x1 > $x2 ? $x2 : $x1;
            for my $j ($i .. $i + abs($x1 - $x2)) {
                $values[$j][$y1]++;
            }
        }
    }

    my $result;
    for my $row (@values) {
        for my $value (@$row) {
            $result++ if $value > 1;
        }
    }

    print "the result is $result\n";

    close $input;
}


sub part2 {
    open my $input, '<', '5.txt';

    my @coordinates;
    while(<$input>) {
        my @coordinate = split '->', $_;
        push @coordinates, \@coordinate;
    }

    my @values;
    for (0 .. 1000) {
        my @arr = (0) x 1000;
        $values[$_] = \@arr;
    }

    for my $coordinate (@coordinates) {
        my @p1 = split ',', $coordinate->[0];
        my @p2 = split ',', $coordinate->[1];

        if ($p1[0] == $p2[0]) {
            my $i = $p1[1] > $p2[1] ? $p2[1] : $p1[1];
            for my $j ($i .. $i + abs($p1[1] - $p2[1])) {
                $values[$p1[0]][$j]++;
            }
        } elsif ($p1[1] == $p2[1]) {
            my $i = $p1[0] > $p2[0] ? $p2[0] : $p1[0];
            for my $j ($i .. $i + abs($p1[0] - $p2[0])) {
                $values[$j][$p1[1]]++;
            }
        } elsif (abs($p1[0] - $p2[0]) == abs($p1[1] - $p2[1])) {
            my @p = $p1[0] > $p2[0] ? @p2 : @p1;

            my $y_index = 0;
            for my $j ($p[0] .. $p[0] + abs($p1[0] - $p2[0])) {
                if ($p[0] < $p1[0]) { #p is p2
                    $values[$j][$p2[1] + $y_index]++;
                    $p1[1] < $p2[1] ? $y_index-- : $y_index++;
                } else { #p is p1
                    $values[$j][$p1[1] + $y_index]++;
                    $p1[1] > $p2[1] ? $y_index-- : $y_index++;
                }
            }
        }
    }

    my $result;
    for my $row (@values) {
        for my $value (@$row) {
            $result++ if $value > 1;
        }
    }

    print "the result is $result\n";

    close $input;
}
