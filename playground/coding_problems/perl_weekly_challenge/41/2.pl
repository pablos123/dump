use strict;
use warnings;

sub main {
    my $n = shift;
    return 1 if($n == 0 || $n == 1);
    return main($n-1) + main($n-2) + 1;
}

print main($_) . "\n" for (1..20);;
