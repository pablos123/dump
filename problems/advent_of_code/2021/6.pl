use strict;
use warnings;

print "============= PART 1 =============\n";
part1();
print "============= PART 2 =============\n";
part2();

exit 0;

sub part1 {
    open my $input, '<', './6.txt';
    my @fishes = split ',', <$input>;

    for (0..79) {
        my @new_gen = ();
        for (my $i = 0; $i < scalar @fishes; ++$i) {
            if($fishes[$i] == 0) {
                $fishes[$i] = 6;
                push @new_gen, 8;
            } else {
                --$fishes[$i];
            }
        }
        push @fishes, @new_gen;
    }

    print "there would be " . scalar @fishes . "\n";

    close $input;
}

sub part2 {
    require bignum;
    open my $input, '<', './6.txt';
    my @fishes = split ',', <$input>;

    my @count = (0) x 9;
    for my $fish (@fishes) {
        $count[$fish]++;
    }

    for (0 ..255) {
        my $count_0 = $count[0];
        $count[0] = $count[1];
        $count[1] = $count[2];
        $count[2] = $count[3];
        $count[3] = $count[4];
        $count[4] = $count[5];
        $count[5] = $count[6];
        $count[6] = $count[7] + $count_0;
        $count[7] = $count[8];
        $count[8] = $count_0;
    }


    my $total = 0;
    for (@count) {
        $total += $_;

    }

    print "there would be " . $total . " fishes\n";

    close $input;
}
