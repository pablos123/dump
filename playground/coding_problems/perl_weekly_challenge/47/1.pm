use strict;
use warnings;

sub roman_to_dec {
    my $arg = shift; 
    
    my @roman = split //, shift; 

    foreach my $letter (@roman) {
       if ($letter == 'I') { $number 
    }


}


sub dec_to_roman {

}


sub main {
    my $arg1 = roman_to_dec($ARGV[0]);
    my $arg2 = roman_to_dec($ARGV[2]);
    $operator = $ARGV[1];
    if    ( $operator eq '+') { dec_to_roman($arg1 + $arg2); }
    elsif ( $operator eq '-') { dec_to_roman($arg1 - $arg2); } 
    elsif ( $operator eq '%') { dec_to_roman($arg1 % $arg2); }
    elsif ( $operator eq '/') { dec_to_roman($arg1 / $arg2); }
    elsif ( $operator eq '*') { dec_to_roman($arg1 * $arg2); }
    else { die 'not an operator'; }
}

main();
