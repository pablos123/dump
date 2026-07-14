use strict;
use warnings;

print "============= PART 1 =============\n";
part1();
print "============= PART 2 =============\n";
part2();

exit 0;

sub part1 {
    open my $input, '<', './10.txt';

    my $answer = 0;
    while (my $line = <$input>) {
        chomp($line);
        my @symbols = split //, $line;
        my @stack = shift @symbols;

        my $is_corrupted;
        while (1) {
            $is_corrupted = 0;

            my $symbol = shift @symbols;
            my $last = $stack[-1];


            if ($symbol) {
                if ($symbol eq '(' || $symbol eq '[' || $symbol eq '{' || $symbol eq '<') {
                    push @stack, $symbol;
                    next;
                }
            } else {
                last;
            }

            if ($symbol eq ')') {
                if ($last ne '(') {
                    push @stack, $symbol;
                    $is_corrupted = 1;
                    last;
                }
                pop @stack;
            } elsif ($symbol eq ']') {
                if ($last ne '[') {
                    push @stack, $symbol;
                    $is_corrupted = 1;
                    last;
                }
                pop @stack;
            } elsif ($symbol eq '}') {
                if ($last ne '{') {
                    push @stack, $symbol;
                    $is_corrupted = 1;
                    last;
                }
                pop @stack;
            } elsif ($symbol eq '>') {
                if ($last ne '<') {
                    push @stack, $symbol;
                    $is_corrupted = 1;
                    last;
                }
                pop @stack;
            }
        }

        if ($is_corrupted) {
            my $symbol = pop @stack;
            print "corrupted line\nthe corrupted symbol is: $symbol\n";

            print "$_  " for @stack;
            print "\n";

            if ($symbol eq ')') {
                $answer += 3;
            } elsif ($symbol eq ']') {
                $answer += 57;
            } elsif ($symbol eq '}') {
                $answer += 1197;
            } elsif ($symbol eq '>') {
                $answer += 25137;
            }
        }
    }

    print "the answer is: $answer\n";

    close $input;
}

sub part2 {
    require bignum;
    open my $input, '<', './10.txt';

    my $answer = 0;
    my @totals;
    while (my $line = <$input>) {
        chomp($line);
        my @symbols = split //, $line;
        my @stack = shift @symbols;

        my $is_corrupted = 0;
        while (1) {
            my $symbol = shift @symbols;
            my $last = $stack[-1];

            if ($symbol) {
                if ($symbol eq '(' || $symbol eq '[' || $symbol eq '{' || $symbol eq '<') {
                    push @stack, $symbol;
                    next;
                }
            } else {
                last;
            }

            if ($symbol eq ')') {
                if ($last ne '(') {
                    push @stack, $symbol;
                    $is_corrupted = 1;
                    last;
                }
                pop @stack;
            } elsif ($symbol eq ']') {
                if ($last ne '[') {
                    push @stack, $symbol;
                    $is_corrupted = 1;
                    last;
                }
                pop @stack;
            } elsif ($symbol eq '}') {
                if ($last ne '{') {
                    push @stack, $symbol;
                    $is_corrupted = 1;
                    last;
                }
                pop @stack;
            } elsif ($symbol eq '>') {
                if ($last ne '<') {
                    push @stack, $symbol;
                    $is_corrupted = 1;
                    last;
                }
                pop @stack;
            }
        }

        if (! $is_corrupted && scalar @stack) {

            print "$_  " for @stack;
            print "\n";
            @stack = reverse @stack;
            my $total = 0;
            for my $symbol (@stack) {
                $total *= 5;
                if($symbol eq '(') {
                    $total++;
                } elsif($symbol eq '[') {
                    $total += 2;
                } elsif($symbol eq '{') {
                    $total += 3;
                } elsif($symbol eq '<') {
                    $total += 4;
                }
            }
            push @totals, $total;
        }
    }

    @totals = sort { $a <=> $b } @totals;
    $answer = $totals[int(scalar @totals / 2)];

    print "the answer is: $answer\n";

    close $input;
}
