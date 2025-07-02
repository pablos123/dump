use strict;
use warnings;

# first employee opens all the doors
my %hotel = map { $_ => 1 } (2..500);

printf "1  ";
for my $employee (sort {$a <=> $b} keys %hotel) {
    for(my $n = $employee; $n <= 500; $n+=$employee) {
        $hotel{$n} = $hotel{$n} ? 0 : 1;
    }
}

for (sort {$a <=> $b} keys %hotel) {
    print "$_   " if $hotel{$_};
}

print "\n";
