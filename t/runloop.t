#!/usr/bin/env perl6

use lib 'lib';
use Benchmark;

my $b = Benchmark.new(:debug(True));

$b.timeit(10, sub{
  sleep 1;
});

$b.timeit(10, sub{
  sleep .5;
});


