my $use-telemetry = True;
(try require ::('Telemetry') <&infix:<->>) === Nil and $use-telemetry = False;

sub get-now(Bool $no-telemetry = False) {
  return now unless $use-telemetry && !$no-telemetry;
  ::('Telemetry').new;
}

class Bench::Time {
  has Numeric  $.wallclock  is rw = 0.0;
  has Numeric  $.cpu-user   is rw = 0.0;
  has Numeric  $.cpu-sys    is rw = 0.0;
  has Numeric  $.cpu        is rw = 0.0;
  has Bool $.telemetry  is rw = $use-telemetry;
  has Int  $.iterations is rw = 0;

  has Bench::Time $.ref;

  method add($time) {
    $.iterations += ($time ~~ Bench::Time ?? $time.iterations !! 1);
    if $time ~~ (Int|Numeric) {
      $.wallclock += $time;
      $.telemetry = False;
      return;
    }
    my $scale = $time ~~ Bench::Time ?? 1 !! 1000000;
    $.wallclock += $time.wallclock / $scale;
    $.cpu-user  += $time.cpu-user / $scale;
    $.cpu-sys   += $time.cpu-sys / $scale;
    $.cpu       += $time.cpu    / $scale;
  }

  method Real {
    $.wallclock;
  }

  method rate(Numeric:D $per-seconds? = 1.0) {
    ($per-seconds / $.wallclock) * $.iterations;
  }

  method compare-cpu-user {
    ($.cpu-user / $.iterations) - ($.ref ?? $.ref.cpu-user / $.ref.iterations !! 0);
  }

  method compare-cpu {
    ($.cpu / $.iterations) - ($.ref ?? $.ref.cpu / $.ref.iterations !! 0);
  }

  method compare-cpu-sys {
    ($.cpu-sys / $.iterations) - ($.ref ?? $.ref.cpu-sys / $.ref.iterations !! 0);
  }

  method compare-wallclock {
    ($.wallclock / $.iterations) - ($.ref ?? $.ref.wallclock / $.ref.iterations !! 0);
  }
}

sub ref {
  my $calla = sub { };
  my ($base, $t0, $t1) = (Bench::Time.new);
  my $ref-ops = $*REFERENCE-OPERATIONS // 10000;
  for (1..$ref-ops) {
    $t0 = get-now;
    $calla();
    $t1 = get-now;
    $base.add($t1 - $t0);
  };
  $base;
}

sub to-num($val) {
  return $val if $val ~~ (Int|Numeric);
  return $val.wallclock.abs if $val ~~ Bench::Time;
  $val.wallclock.abs / 1000000;
}

class Bench {
  has Int  $.debug        = 3; #0-2, info warn error
  has Int  $.min-count    = 4;
  has Numeric  $.min-cpu      = .04;
  has Str  $.format       = '%1.3f';
  has Str  $.style        = 'auto';
  has Bool $.no-telemetry = False;

  has Bench::Time $!empty-sub;

  submethod TWEAK(|) {
    self!log(0,'TWEAK');
    self!log(0,'timing empty sub ' ~ ($*REFERENCE-OPERATIONS//10000) ~ ' x for reference');
    $!empty-sub = ref;
    self!log(0, '  result: ' ~ $!empty-sub.compare-wallclock);
  }

  method !log(Int $level, *@rest) {
    return if $level < $.debug;
    $*ERR.say: $_ for @rest;
  }

  method timestr(Bench::Time $t, :$style = $.style, :$format = $.format) {
    my $ret = '';
    if !$.no-telemetry && $use-telemetry {
      $ret ~= sprintf("$format wallclock secs ($format usr $format sys $format cpu)",
        $t.wallclock,
        $t.cpu-user,
        $t.cpu-sys,
        $t.cpu,
      );
    } else {
      $ret ~= sprintf("$format wallclock secs", $t.wallclock);
    }
    my $elapsed = $t.compare-wallclock;
    $ret ~= sprintf(" \@ $format/s (n=%d)", $t.rate, $t.iterations);
    $ret;
  }

  multi method timethis(Numeric:D $iterations, Str:D $callable, Str $title? = 'time') {
    self!log(0, 'timethis(Numeric,Str,Str)');
    $.timethis($iterations, $callable.EVAL, $title);
  }

  multi method timethis(Numeric:D $iterations, Callable:D $callable, Str $title? = 'time') {
    self!log(0, 'timethis(Numeric,Callable,Str)');
    my $time;
    if $iterations <= 0 {
      $time = $.countit($iterations.abs, $callable);
    } else {
      $time = $.timeit($iterations.Int, $callable);
    }
    say sprintf("%10s: %s", $title, $.timestr($time));
    say ' ' x 15, '(warning: too few iterations for a reliable count)'
      if $time.iterations < 1000;
    $time;
  }

  multi method timethese(Numeric:D $iterations, %timeables) {
    self!log(0, 'timethese(Numeric,*%)');
    my %times;
    say 'Benchmark: ';
    say "Timing {$iterations.Int.abs} iterations of {%timeables.keys.sort.join(', ')}..."
      if $iterations > 0;
    say "Running {%timeables.keys.sort.join(', ')} for at least {$iterations.abs} seconds..."
      if $iterations <= 0;
    for %timeables.sort({$^a.key cmp $^b.key}) -> $kv {
      %times{$kv.key} = $.timethis($iterations, $kv.value, $kv.key);
    }
    %times;
  }

  multi method timeit(Int:D $iterations where * >= 0, Str:D $evalable) {
    self!log(0, 'timeit(Int,Str);');
    $.timeit($iterations, $evalable.EVAL);
  }

  method cmpthese(Numeric:D $iterations, %timeables) {
    self!log(0, 'cmpthese(Int,Str);');
    my %results = $.timethese($iterations, %timeables);
    my @maxes = (1, $iterations > 0 ?? 4 !! 6);
    %results.keys.sort.map({@maxes.push: .chars});
    my @cols = ' ', $iterations > 0 ?? 'Rate' !! 's/iter', |%results.keys.sort;
    my @rows;
    for %results.keys.sort -> $res-key {
      my (@row, $value, $f);
      @row.push($res-key);
      @maxes[0] = ($res-key.chars, @maxes[0]).max;
      $value = $iterations > 0 ?? %results{$res-key}.rate !! 1 / %results{$res-key}.iterations;
      given $value {
        when $_ >= 100 { $f = '%0.0f' };
        when $_ >= 10  { $f = '%0.1f' };
        when $_ >= 1   { $f = '%0.2f' };
        when $_ >= 0.1 { $f = '%0.3f' };
        default        { $f = '%0.2e' };
      };
      $f ~= '/s' if $iterations > 0;
      @row.push(sprintf($f, $value));
      @maxes[1] = (@row[*-1].chars, @maxes[1]).max;
      my $i = 2;
      for %results.keys.sort -> $val-key {
        my $out = '';
        if %results{$res-key}.compare-wallclock eq %results{$val-key}.compare-wallclock {
          $out ~= '--';
        } else {
          $out = sprintf('%.0f%%', 100 * %results{$res-key}.compare-wallclock / %results{$val-key}.compare-wallclock - 100);
        }
        @row.push($out);
        @maxes[$i] = (@row[*-1].chars, @maxes[$i]).max;
        $i++;
      }
      @rows.push(@row);
    }
    my $sep = sub (:@vals?, :$fill?, :$j? = 'O') {
      return $j ~ @maxes.map({ $fill x $_+2 }).join($j) ~ $j if $fill;
      $j ~ (0..@maxes.end).map({ ' ' ~ @vals[$_] ~ (' ' x (@maxes[$_] - @vals[$_].chars + 1)) }).join($j) ~ $j;
    }
    say $sep(:fill<->);
    say $sep(:vals(@cols), :j<|>);
    say $sep(:fill<=>);
    say $sep(vals => $_, :j<|>) for @rows;
    say $sep(:fill<->);
  }

  multi method timeit(Int:D $iterations where * >= 0, Callable:D $callable) {
    self!log(0, 'timeit(Int,Callable)');
    my $total-time = self.runloop($iterations.abs, $callable);
    my $less-empty = $total-time.compare-wallclock;
    self!log(0, '   loops: ' ~ $iterations.abs);
    self!log(0, '    time: ' ~ $total-time.wallclock);
    self!log(0, '     avg: ' ~ ($total-time.wallclock / $iterations));
    self!log(0, '  -empty: ' ~ $less-empty);
    self!log(2, '  not using reference of empty sub because < 0 problems')
      if $less-empty < 0;
    $total-time;
  }

  multi method countit(Numeric:D $time where * >= 0.0, Str:D $evalable) {
    self!log(0, 'countit(Numeric,Str)');
    $.countit($time, $evalable.EVAL);
  }

  multi method countit(Numeric:D $time where * >= 0.0, Callable:D $callable) {
    self!log(0, 'countit(Numeric,Str)');
    my $total-time = self.runloop(1, $callable);
    my $x;
    while ($total-time.wallclock < $time) {
      $x = self.runloop(1, $callable);
      $total-time.add($x);
    }
    $total-time;
  }

  method runloop(Int:D $iterations, Callable:D $c) {
    self!log(-1, 'runloop(Int,Callable)');
    my ($time, $t0, $t1, $t) = (Bench::Time.new(:ref($!empty-sub)));
    my $negatives = 0;
    for (1..$iterations) {
      $t0    = get-now($.no-telemetry);
      $c();
      $t1    = get-now($.no-telemetry);
      $t     = to-num($t1 - $t0);
      $time.add($t1 - $t0);
      if ($t - $!empty-sub.compare-wallclock) < -0.001 {
        self!log(1, 'runloop encountered close to 0.0s loop (diff:'~($t-$!empty-sub.compare-wallclock)~')');
        $negatives++;
      }
    }
    $time;
  }
}
