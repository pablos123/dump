# Agregar un elemento al principio de un array con una cantidad finita de posiciones
# Como mínimo, el array tiene un valor definido en la primera posición; las restantes pueden estar vacías, pero no puede haber posiciones vacías entre valores.
# Si el elemento ya existe en el array, en una posición distinta de la primera, se debe reubicar al principio.
# Si no existe, se lo debe ubicar en la primera posición.
# Si no hubiera posiciones disponibles retorna error.
# Los demás elementos definidos tienen que persistir en el array (preferentemente, manteniendo el orden)

use strict;
use warnings;

my ($al, $e, $mai, $inserted, $i, $max_i, @arr, %ins);

print 'Array length: ';
$al = <stdin>;
chomp $al;
die 'Hey! The array must have at least 1 element...' if $al < 1;

print 'Insert elements for the array (minimun 1): ';
print "<Ctrl>-D to Terminate \n";
@arr = <stdin>;
chomp @arr;

$mai = $#arr;
die 'Mmm... The minimun quantity of elements is 1...' if ( $mai + 1 < 1);

die 'Mmm... The quantity of elements in the array is bigger than the array length...' if ($mai - 1) > $al;

$i = 0;
$ins{$_} = $i++ for @arr;

print 'Array status: ';
print "$_ " for @arr;
print "\n";

while(1) {
    print 'Insert element: ';
    $e = <stdin>;
    chomp $e;

    if(exists $ins{$e}) {
        $inserted = 1;
    } elsif($mai + 1 < $al) {
        $inserted = 0;
    } else {
        print "There is no more space in the array... Try with an already existing element!\n";
        next;
    }

    $max_i = $inserted ? $ins{$e} : ++$mai;

    if($max_i > 0) {
        for($i = $max_i; $i > 0; --$i) {
            $arr[$i] = $arr[$i - 1];
            $ins{$arr[$i]} = $i;
        }
    }

    $arr[0] = $e;
    $ins{$e} = 0;

    print 'Array status: ';
    print "$_ " for @arr;
    print "\n";
}

1;
