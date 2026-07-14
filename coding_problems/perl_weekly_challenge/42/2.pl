use strict;
use warnings;

my @chars = ('(', ')');
my @brackets = ();

#generate string
for (0..5) {
    push @brackets, $chars[int(rand(2))];
}

print @brackets, "   ", check_brackets(), "\n";

sub check_brackets {
    my $count;
    for (@brackets) {
        if ($_ eq '(') {
            $count++;
            next;
        }
        --$count;
        return 'NOT OK' if $count < 0;
    }
    if (!$count) {
        return 'OK'; 
    };
    return 'NOT OK';
}

