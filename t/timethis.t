#!/usr/bin/env perl6

use lib 'lib';
use Benchmark;

my $b = Benchmark.new(:debug(False));

my $r = $b.timethis(50, sub{
  sleep .005;
}, :title('Hades'));

