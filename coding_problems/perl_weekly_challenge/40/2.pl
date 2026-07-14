use strict;
use warnings;

sub main {
    my $arr = <STDIN>;
    chomp $arr;
    my $pos = <STDIN>;
    chomp $pos;

    my @arr = split / /, $arr;
    my @pos = split / /, $pos;

    my @sorted = sort {$a <=> $b} @arr[@pos];
    @arr[@pos] = @sorted;
    
    print $_ . '  ' foreach @arr;
    return 0;
}

main();
