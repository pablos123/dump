$var = <stdin>;
chomp($var);
$var =~ s/ //g;

@ss;
$new_ss = substr $var, 0, 8;

push @ss, $new_ss;

while(length $new_ss == 8) {
   $new_ss = substr $var, (scalar @ss * 8), 8;
   push @ss, $new_ss;
}

for $number (0..7) {
    for $string (@ss) {
        $char = substr $string, $number, 1;
        if(defined $char) {
            printf "$char";
        }
    }
    printf " ";
}

printf("\n");
