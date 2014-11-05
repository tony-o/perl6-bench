#!/usr/bin/env perl6

use lib 'lib';
use Benchmark;

my $b = Benchmark.new(:debug(True));

say $b.timeit(10, sub{
  sleep 500;
});

say $b.timeit(1000000, sub{
  sleep 500;
});


