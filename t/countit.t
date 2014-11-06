#!/usr/bin/env perl6

use lib 'lib';
use Benchmark;

my $b = Benchmark.new(:debug(False));

my $r = $b.countit(5, sub{
  sleep .005;
});

$r.perl.say;
