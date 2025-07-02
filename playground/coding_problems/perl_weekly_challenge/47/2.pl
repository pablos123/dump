use constant MAX => 20;

$count;
$n = 100;
while($count != MAX) {
    @n = split //, $n;
    $v = $n[0] . $n[-1];
    if ($n % $v == 0) {
        print "$n   "; 
        $count++;
    }
    $n++;
}

