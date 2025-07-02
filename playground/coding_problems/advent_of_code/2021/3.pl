use strict;
use warnings;

print "============= PART 1 =============\n";
part1();
print "============= PART 2 =============\n";
part2();

exit 0;

sub part1 {
    open my $input, '<', '3.txt';

    my ($gamma, $epsilon, $answer);
    my @count;

    while (<$input>) {
        my @bits = split '', $_;

        for (my $i = 0; $i < 12; ++$i) {
            $count[$i] += $bits[$i];
        }
    }

    for (my $i = 0; $i < 12; ++$i) {
        $gamma     .= $count[$i] > 500 ? '1' : '0';
        $epsilon   .= $count[$i] < 500 ? '1' : '0';
    }

    print "gamma: $gamma, epsilon: $epsilon\n";

    $gamma = eval "0b$gamma";
    $epsilon = eval "0b$epsilon";
    $answer = $gamma * $epsilon;

    print "in decimal: $gamma, $epsilon\n";
    print "the multiplication is: $answer\n";

    close $input;
}

sub part2 {
    open my $input, '<', '3.txt';

    my ($count, $answer, $oxygen_generator_rating, $CO2_scrubber_rating);
    my @input;

    while (<$input>) {
        my @bits = split '', $_;
        push @input, \@bits;
    }

    my @filtered_oxygen = @input;
    my @filtered_CO2    = @input;

    for (my $i = 0; $i < 12; ++$i) {

        unless (scalar @filtered_oxygen == 1) {
            $count = 0;
            $count += $_->[$i] for (@filtered_oxygen);

            my $oxygen_filter = $count >= int(scalar @filtered_oxygen / 2) ? '1' : '0';

            @filtered_oxygen = grep {$_->[$i] == $oxygen_filter} @filtered_oxygen;
        }

        unless (scalar @filtered_CO2 == 1) {
            $count = 0;
            $count += $_->[$i] for (@filtered_CO2);

            my $CO2_filter = $count < int(scalar @filtered_CO2 / 2) > 0 ? '1' : '0';

            @filtered_CO2 = grep {$_->[$i] == $CO2_filter} @filtered_CO2;
        }

        last if scalar @filtered_CO2 == 1 and scalar @filtered_oxygen == 1;

        die if $i == 11; # not possible
    }


    print "oxygen_generator_rating: @{$filtered_oxygen[0]}";
    print "CO2_scrubber_rating: @{$filtered_CO2[0]}";

    $oxygen_generator_rating = join '', @{$filtered_oxygen[0]};
    $CO2_scrubber_rating = join '', @{$filtered_CO2[0]};

    $oxygen_generator_rating = eval "0b$oxygen_generator_rating";
    $CO2_scrubber_rating = eval "0b$CO2_scrubber_rating";
    $answer = $oxygen_generator_rating * $CO2_scrubber_rating;

    print "in decimal: $oxygen_generator_rating, $CO2_scrubber_rating\n";
    print "the multiplication is: $answer\n";

    close $input;
}
