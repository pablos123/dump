$dna = $ARGV[0] || 'GTAAACCCCTTTTCATTTAGACAGATCGACTCCTTATCCATTCTCAGAGATGTGTTGCTGGTCGCCG';

$ac = () = $dna =~ /A/g;
$tc = () = $dna =~ /T/g;
$cc = () = $dna =~ /C/g;
$gc = () = $dna =~ /G/g;

print "count:\n";
print "A: $ac, T: $tc, C: $cc, G: $gc\n";

$dna =~ tr/TAGC/uxyz/;
$dna =~ tr/uxyz/ATCG/;

print "also:\n";
print "$dna\n";

