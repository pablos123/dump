use strict;
use warnings;

print "============= PART 1 =============\n";
part1();
print "============= PART 2 =============\n";
part2();

exit 0;

sub part1 {
    open my $input, '<', './8.txt';
    my $total = 0;
    while (<$input>) {
        $_ =~ /^.*\|([a-g ]*)\n?$/;
        my $count = () = $1 =~ /(?<= )([a-g]{2,4}|[a-g]{7})(?= |$)/g;
        $total += $count;
    }

    print "the answer is: $total\n";

    close $input;
}

sub part2 {
    open my $input, '<', './8.txt';
    my $total = 0;
    while (<$input>) {
        my $value = '';
        $_ =~ /(^.*)\|([a-g ]*)\n?$/;
        my $wires = $1;
        my @wir_str = split / /, $wires;
        @wir_str = sort { length $a <=> length $b } @wir_str;

        my %display = ();
        for my $letter ('a'..'g') {
            my $count = ()  = $wires =~ /$letter/g;
            $display{b} = $letter if $count == 6;
            $display{e} = $letter if $count == 4;
            $display{f} = $letter if $count == 9;
        }

        for my $wire (@wir_str) {
            if (length $wire == 2) {
                my $rgx = qr|[^$display{f}]|;
                $wire =~ /$rgx/;
                $display{c} = $&;
            } elsif (length $wire == 3) {
                my $rgx = qr|[^$display{f}$display{c}]|;
                $wire =~ /$rgx/;
                $display{a} = $&;
            } elsif (length $wire == 4) {
                my $rgx = qr|[^$display{f}$display{c}$display{b}]|;
                $wire =~ /$rgx/;
                $display{d} = $&;
            } elsif (length $wire == 7) {
                my $rgx = qr|[^$display{a}$display{b}$display{c}$display{d}$display{e}$display{f}]|;
                $wire =~ /$rgx/;
                $display{g} = $&;
            }
        }

        my @digits = split / /, $2;

        for my $digit (@digits) {
            next if ! $digit;
            if (length $digit == 2) {
                $value .= '1';
            } elsif (length $digit == 3) {
                $value .= '7';
            } elsif (length $digit == 4) {
                $value .= '4';
            } elsif (length $digit == 5) {
                my $is_2 = qr|[$display{a}$display{c}$display{d}$display{e}$display{g}]|;
                my $is_3 = qr|[$display{a}$display{c}$display{d}$display{f}$display{g}]|;
                my $count_2  = () = $digit =~ /$is_2/g;
                my $count_3  = () = $digit =~ /$is_3/g;
                if($count_2 == 5) {
                    $value .= '2';
                } elsif ($count_3 == 5) {
                    $value .= '3';
                } else {
                    $value .= '5';
                }
            } elsif (length $digit == 6) {
                my $is_0 = qr|[$display{a}$display{b}$display{c}$display{e}$display{f}$display{g}]|;
                my $is_6 = qr|[$display{a}$display{b}$display{d}$display{e}$display{f}$display{g}]|;
                my $count_0  = () = $digit =~ /$is_0/g;
                my $count_6  = () = $digit =~ /$is_6/g;
                if($count_0 == 6) {
                    $value .= '0';
                } elsif ($count_6 == 6) {
                    $value .= '6';
                } else {
                    $value .= '9';
                }
            } elsif (length $digit == 7) {
                $value .= '8';
            }
        }

        $total += $value;
    }

    print "the answer is: $total\n";

    close $input;
}
