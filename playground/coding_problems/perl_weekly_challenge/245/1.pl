# Input: @lang = ('c++', 'haskell', 'java')
#        @popularity = (1, 3, 2)
# Output: ('c++', 'java', 'haskell')

use strict;
use warnings;

my @lang = ('c++', 'haskell', 'java');
my @popularity = (1, 3, 2);

my ($arr, $counter) = ([], 0);
for (@popularity) {
    $arr->[$_] = $lang[$counter++]
}

for (@$arr) { print "'$_' " if $_; }
print "\n"
# Output: ('c++', 'java', 'haskell')
