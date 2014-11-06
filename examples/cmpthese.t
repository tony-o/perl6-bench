#!/usr/bin/env perl6

use lib 'lib';
use Benchmark;

my $b = Benchmark.new(:debug(False));

my $r = $b.cmpthese(5, {
  hades => sub{
    sleep 2;
  },
  sleepy => sub{
    sleep 3;
  },
  fast => sub{
    sleep 1;
  }
});

