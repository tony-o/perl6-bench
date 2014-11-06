
use lib 'lib';
use Benchmark;
use Test;

plan 1;

my $b = Benchmark.new;

ok 4.5 < $b.timethis(1, sub { sleep 5; })[0] < 5.5, 'Timing test';

done;
