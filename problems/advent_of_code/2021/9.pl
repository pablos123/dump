use strict;
use warnings;

print "============= PART 1 =============\n";
part1();
print "============= PART 2 =============\n";
part2();

exit 0;

sub part1 {
    open my $input, '<', './9.txt';
    my @limit_row = (99) x 100;
    my @matrix = \@limit_row;

    while (<$input>) {
        chomp($_);

        my @row = split //, $_;
        unshift @row, 99;
        push @row, 99;

        push @matrix, \@row;
    }

    push @matrix, \@limit_row;

    my @low_points = ();
    for (my $i = 1; $i < scalar @matrix; ++$i) {
        for (my $j = 1; $j < scalar @{$matrix[$i]} - 1; ++$j) {
            if( $matrix[$i][$j] < $matrix[$i][$j+1] &&
                $matrix[$i][$j] < $matrix[$i][$j-1] &&
                $matrix[$i][$j] < $matrix[$i+1][$j] &&
                $matrix[$i][$j] < $matrix[$i-1][$j]
            ) {
                push @low_points, $matrix[$i][$j];
            }
        }
    }

    my $answer = scalar @low_points;
    $answer += $_ for @low_points;

    print "the answer is: $answer\n";

    close $input;
}

sub part2 {
    open my $input, '<', './9.txt';
    my @limit_row = (9) x 102;
    my @matrix = \@limit_row;

    while (<$input>) {
        chomp($_);

        my @row = split //, $_;
        unshift @row, 9;
        push @row, 9;

        push @matrix, \@row;
    }

    push @matrix, \@limit_row;

    my @low_points = ();
    for (my $i = 1; $i < scalar @matrix; ++$i) {
        for (my $j = 1; $j < scalar @{$matrix[$i]} - 1; ++$j) {
            if( $matrix[$i][$j] < $matrix[$i][$j+1] &&
                $matrix[$i][$j] < $matrix[$i][$j-1] &&
                $matrix[$i][$j] < $matrix[$i+1][$j] &&
                $matrix[$i][$j] < $matrix[$i-1][$j]
            ) {
                my @point = ($i, $j);
                push @low_points, \@point;
            }
        }
    }


    my $is_used = sub {
        my ($array, $i, $j) = @_;
        for (@$array) {
            return 1 if $_->[0] == $i && $_->[1] == $j;
        }
        return 0;
    };

    my @basin_values;
    for my $low_point (@low_points) {
        my @stack = ($low_point);
        my $answer;
        my @used = ($low_point);
        while (scalar @stack > 0) {
            my $point_ref = pop @stack;
            my @point = @$point_ref;
            $answer++;

            die "$matrix[$point[0]][$point[1] + 1] y: $point[1]" if $point[0] == 101;
            if($matrix[$point[0]][$point[1] + 1] < 9 && ! $is_used->(\@used, $point[0], $point[1] + 1)) {
                my @new_point = ($point[0], $point[1] + 1);
                push @used, \@new_point;
                push @stack, \@new_point;
            }
            if($matrix[$point[0]][$point[1] - 1] < 9 && ! $is_used->(\@used, $point[0], $point[1] - 1)) {
                my @new_point = ($point[0], $point[1] - 1);
                push @used, \@new_point;
                push @stack, \@new_point;
            }
            if($matrix[$point[0] + 1][$point[1]] < 9 && ! $is_used->(\@used, $point[0] + 1, $point[1])) {
                my @new_point = ($point[0] + 1, $point[1]);
                push @used, \@new_point;
                push @stack, \@new_point;
            }
            if($matrix[$point[0] - 1][$point[1]] < 9 && ! $is_used->(\@used, $point[0] - 1, $point[1])) {
                my @new_point = ($point[0] - 1, $point[1]);
                push @used, \@new_point;
                push @stack, \@new_point;
            }
        }

        push @basin_values, $answer;
    }

    @basin_values = reverse sort { $a <=> $b } @basin_values;
    my $answer = $basin_values[0] * $basin_values[1] * $basin_values[2];

    print "the answer is: $answer\n";

    close $input;
}


sub printm {
    my $matrix = shift;
    for my $row (@$matrix) {
        for my $column (@$row) {
            print "$column  ";
        }
        print "\n";
    }
}
