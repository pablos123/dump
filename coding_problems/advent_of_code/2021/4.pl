use strict;
use warnings;

print "============= PART 1 =============\n";
part1();
print "============= PART 2 =============\n";
part2();

exit 0;

sub part1 {
    open my $input, '<', '4.txt';

    my @numbers = split ',', <$input>;
    my @matrixes;
    my $row = '';

    while (my $line = <$input>) {
        my @matrix;
        while ($line && $line ne "\n") {
            chomp($line);
            my @row = split ' ', $line;

            push @matrix, \@row;
            $line = <$input>;
        }

        push @matrixes, \@matrix;
    }

    my $check_winner = sub {
        my $matrix = shift;

        my @count_column = (0, 0, 0, 0, 0);
        for my $row (@$matrix) {
            my $count_row = 0;
            my $index = 0;
            for my $column (@$row) {
                if($column == -1) {
                    $count_row++;
                    $count_column[$index]++;
                }
                ++$index;
            }

            return 1 if $count_row == 5;
        }

        for (@count_column) {
            return 1 if $_ == 5;
        }
    };

    my $winner_matrix;
    my $last_number;

    for my $number (@numbers) {
        for my $matrix (@matrixes) {
            for my $row (@$matrix) {
                my $index = 0;
                for my $column (@$row) {
                    $row->[$index] = -1 if $column == $number;
                    if ($check_winner->($matrix)) {
                        $winner_matrix = $matrix;
                        $last_number = $number;
                        goto is_bad;
                    }
                    ++$index;
                }
            }
        }
    }

    is_bad:

    my $print_matrix = sub {
        my $matrix = shift;
        for my $row (@$matrix) {
            for my $column (@$row) {
                print "$column  ";
            }
            print "\n";
        }
    };

    my $get_sum = sub {
        my $matrix = shift;
        my $total;
        for my $row (@$matrix) {
            for my $column (@$row) {
                $total += $column unless $column == -1;
            }
        }

        return $total;
    };

    print "the winner board is: \n";
    $print_matrix->($winner_matrix);
    print ":D\n";

    my $sum_of_unmarked = $get_sum->($winner_matrix);
    print "the answer is:  " . $sum_of_unmarked * $last_number . "\n";

    close $input;
}

sub part2 {
    open my $input, '<', '4.txt';

    my @numbers = split ',', <$input>;
    my @matrixes;
    my $row = '';

    while (my $line = <$input>) {
        my @matrix;
        next if $line eq "\n";
        while ($line && $line ne "\n") {
            chomp($line);
            my @row = split ' ', $line;

            push @matrix, \@row;
            $line = <$input>;
        }

        push @matrixes, \@matrix;
    }

    my $total_matrixes = scalar @matrixes;

    my $check_winner = sub {
        my $matrix = shift;

        my @count_column = (0, 0, 0, 0, 0);
        for my $row (@$matrix) {
            my $count_row = 0;
            my $index = 0;
            for my $column (@$row) {
                if($column == -1) {
                    $count_row++;
                    $count_column[$index]++;
                }
                ++$index;
            }

            return 1 if $count_row == 5;
        }

        for (@count_column) {
            return 1 if $_ == 5;
        }
    };

    my $bad_matrix;
    my $last_number;
    my $total_winners;

    my @winners = (0) x 100;

    for my $number (@numbers) {
        my $matrix_index = 0;
        for my $matrix (@matrixes) {
            if($winners[$matrix_index]) {
                $matrix_index++;
                next;
            }

            my $win_flag = 0;
            for my $row (@$matrix) {
                my $index = 0;
                for my $column (@$row) {
                    $row->[$index] = -1 if $column == $number;
                    if ($check_winner->($matrix)) {
                        $total_winners++;
                        if($total_winners == $total_matrixes) {
                            $bad_matrix = $matrix;
                            $last_number = $number;
                            goto is_bad;
                        }
                        $win_flag = 1;
                        last;
                    }
                    ++$index;
                }
                if ($win_flag) {
                    $winners[$matrix_index] = 1;
                    last;
                }
            }
            ++$matrix_index;
        }
    }

    is_bad:

    my $print_matrix = sub {
        my $matrix = shift;
        for my $row (@$matrix) {
            for my $column (@$row) {
                print "$column  ";
            }
            print "\n";
        }
    };

    my $get_sum = sub {
        my $matrix = shift;
        my $total;
        for my $row (@$matrix) {
            for my $column (@$row) {
                $total += $column unless $column == -1;
            }
        }

        return $total;
    };

    print "the loser board is: \n";
    $print_matrix->($bad_matrix);
    print "D:\n";

    my $sum_of_unmarked = $get_sum->($bad_matrix);
    print "the answer is:  " . $sum_of_unmarked * $last_number . "\n";

    close $input;
}
