use strict;
use warnings;

my @arr = (9, 5, 7);
# con gasp0i

my $sum = 0;

$sum += $_ for @arr;
if (not $sum % 3) {
    my @asdf = reverse sort { $a <=> $b } @arr;

    print @asdf;
    exit 0;
}
print(-1);
exit 0;

