#the script supports spaces in the messages
#if there is no character in the matrix it just finds null
# you can do it 
open $fh, '<', './message';

$res = '';
#to support spaces at the end
$length = length <$fh>;
$lc = 0;
while (<$fh>) {
    $lc++;
    $length = length $_ if $length < length $_;
}

$lenght-- if ($length % 2 == 1);

for ($n; $n < $length; $n += 2) {
    open $fh, '<', './message';
    $inverted = '';
    while (<$fh>) {
        if (substr $_, $n, 1) {
            $inverted .= substr $_, $n, 1;
        } else {
            $inverted .= ' ';
        }
    }
    $mcc = 0;
    $max = 0;
    for (0..$lc) {
        $char = substr $inverted, $_, 1;
        $count = grep { $char eq $_} split //, $inverted;
        $count;
        if ($count > $max) {
            $mcc = $char;
            $max = $count;
        }
    }
    $res .= $mcc;
}

print $res;
