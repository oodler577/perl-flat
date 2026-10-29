#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Time::HiRes qw(time);
use Cwd qw(abs_path);
use File::Spec;
my ($baseline,$iterations,$startups)=(undef,500,10);
GetOptions('baseline=s'=>\$baseline,'iterations=i'=>\$iterations,'startups=i'=>\$startups) or die "invalid options\n";
die "usage: perl author/bench-parser.pl --baseline /path/to/previous/checkout [--iterations 500 --startups 10]\n"
    unless defined($baseline) && $iterations>0 && $startups>0;
my $current=abs_path('lib');
$baseline=abs_path(File::Spec->catdir($baseline,'lib'));
die "baseline must contain lib/FLAT/Regex/Parser.pm\n" unless defined($baseline) && -f "$baseline/FLAT/Regex/Parser.pm";
my $worker=<<'WORKER';
use FLAT::Regex::WithExtraOps;
use Time::HiRes qw(time);
my @corpus=('a','ab*c','(a+b)*c','[open][close]+[]','(ab&cd)+(ef&g)','(a+b)&(c+d)','~(ab+c)');
my $t=time;
for (1..$ARGV[0]) {
    for my $s (@corpus) { FLAT::Regex::WithExtraOps->new($s) }
}
printf "%.6f\n",time-$t;
WORKER
print "# perl=$^X version=$] iterations=$iterations startups=$startups\n";
print "backend,stage,iterations,seconds\n";
for my $entry (['baseline',$baseline],['native',$current]) {
    my ($name,$lib)=@$entry;
    my $t=time;
    for (1..$startups) {
        system($^X,"-I$lib",'-MFLAT::Regex::WithExtraOps','-e','1')==0 or die "startup worker failed\n";
    }
    printf "%s,startup,%d,%.6f\n",$name,$startups,time-$t;
    open my $fh,'-|',$^X,"-I$lib",'-e',$worker,$iterations or die "cannot start worker: $!\n";
    my $seconds=<$fh>;
    close $fh or die "parse worker failed\n";
    chomp $seconds;
    print "$name,parse,",7*$iterations,",$seconds\n";
}
