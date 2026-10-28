use strict;
use warnings;
use Test::More;
use IPC::Open3;
use File::Temp qw(tempfile tempdir);
use File::Spec;
use JSON::PP;
use FLAT::CLI;
use FLAT::JFLAP;

my $script = File::Spec->rel2abs('bin/fash');
my $dir = tempdir(CLEANUP=>1);
my %exercised;
ok(-x $script, 'fash is an executable command');
sub cli {
    my ($input, @args) = @_;
    $exercised{$_} = 1 for grep { exists {map {$_=>1} FLAT::CLI->commands}->{$_} } @args;
    my ($out) = tempfile(DIR=>$dir);
    my ($err) = tempfile(DIR=>$dir);
    my $pid = open3(my $in, '>&'.fileno($out), '>&'.fileno($err), $^X, '-Ilib', $script, @args);
    print $in $input if defined $input;
    close $in;
    waitpid $pid, 0;
    my $status = $? >> 8;
    seek $out, 0, 0; seek $err, 0, 0;
    local $/;
    return ($status, scalar(<$out>) // '', scalar(<$err>) // '');
}
sub successful {
    my ($input, $args, $pattern, $name) = @_;
    my ($status, $out, $err) = cli($input, @$args);
    is($status, 0, "$name: exit 0");
    like($out, $pattern, "$name: output") if defined $pattern;
    is($err, '', "$name: no stderr");
    return $out;
}
for my $case (
    [['--help'], qr/Exit codes:/], [['help'], qr/Usage:/],
    [['help','test'], qr/Usage: fash test/], [['--version'], qr/FLAT 1\.0\.4/],
    [['normalize','0'], qr/^0\n$/], [['perl-regex','ab*'], qr/\\A.*\\z/], [['dump','a'], qr/FLAT::Regex/],
    [['summary','a'], qr/States/], [['show','a','--format','json'], qr/"transitions"/],
    [['test','[]+0','','0'], qr/\(\+\): \n\(\+\): 0\n/],
    [['test','[foo][bar]','--tokens','["foo","bar"]'], qr/\(\+\)/],
    [['trace','ab','ab'], qr/^\[\[/],
    [['test','[]','--tokens','[]'], qr/\(\+\)/],
    [['compare','a&b','ab+ba'], qr/^Yes/], [['subset','a','a+b'], qr/^Yes/],
    [['empty','#'], qr/^Yes/], [['finite','ab'], qr/^Yes/],
    [['alphabet','a+b'], qr/^\["a","b"\]/],
    [['union','a','b'], qr/^a\+b/], [['concat','a','b'], qr/^ab/],
    [['shuffle','a','b'], qr/^a&b/], [['star','a'], qr/^a\*/],
    [['reverse','ab','--format','json'], qr/"start"/],
    [['intersect','a+b','b','--format','json'], qr/"accepting"/],
    [['difference','a+b','b'], qr/States/], [['symdiff','a','b'], qr/States/],
    [['complement','a'], qr/States/],
    [['random_re','--seed','5','--length','3'], qr/\S/],
    [['random_pre','--seed','5','--length','3'], qr/\S/],
    [['somestrings','[]+0'], qr/^\n0\n$/],
    [['morestrings','a*','3'], qr/^\na\naa\n$/],
    [['strings','[foo][bar]','--delimiter','|'], qr/^foo\|bar\n$/],
) { successful('', $case->[0], $case->[1], join(' ', @{$case->[0]})) }
for my $command (grep {/2/} FLAT::CLI->commands) {
    my $pattern = $command =~ /jflap/ ? qr/<structure>/
        : $command =~ /undgv/ ? qr/^graph G/
        : $command =~ /gv/ ? qr/^digraph G/ : qr/^\d+\n/;
    successful('', [$command,'a&b'], $pattern, "legacy $command");
}
for my $type (qw(pfa nfa dfa min-dfa)) {
    successful('', ['show','a&b','--type',$type,'--format','json'], qr/"states"/, "show $type");
}
for my $format (qw(summary dot undot gdl jflap digraph undirected json)) {
    successful('', ['show','a','--format',$format], qr/\S/, "format $format");
}
successful("a*\r\n\r\naaa", ['-b','test'], qr/\(\+\): \n\(\+\): aaa\n/, 'CRLF batch with empty word and no final newline');
successful("[]+0\n", ['test','-','0'], qr/\(\+\): 0/, 'expression on stdin');
successful("\n0\n", ['test','[]+0'], qr/\(\+\): \n\(\+\): 0/, 'words on stdin');
successful('', ['test','[ ]',' '], qr/\(\+\)/, 'spaces stay data');
successful('', ['test','[$name]','--tokens','["$name"]'], qr/\(\+\)/, 'dollar sign stays data');
successful('', ['test','[a"b]','--tokens','["a\\"b"]'], qr/\(\+\)/, 'quotes stay data');
successful('', ['show','[a"b]','--format','dot'], qr/a\\"b/, 'Graphviz label escaping');
my $limited = successful('', ['strings','a+b+c','--limit','1'], qr/^[abc]\n$/, 'word limit');
my (undef,$random1) = cli('', 'random_pre','--seed','577');
my (undef,$random2) = cli('', 'random_pre','--seed','577');
is($random1,$random2,'seeded random generation is reproducible');
for my $args (
    ['test','a','b'], ['compare','a','b'], ['subset','a+b','a'],
    ['empty','a'], ['finite','a*'],
) {
    my ($status,$out,$err) = cli('', @$args);
    is($status,1,"negative predicate @$args"); is($err,'','false is not an error');
}
my ($quiet,$qout,$qerr)=cli('', 'compare','a','b','--quiet');
is($quiet,1,'quiet retains false exit'); is($qout,'','quiet suppresses result'); is($qerr,'','quiet no error');
for my $args (
    [], ['unknown'], ['test'], ['test','a'], ['compare','a'], ['compare','a','b','c'],
    ['normalize','('], ['normalize','~a'], ['perl-regex','a&b'], ['--bogus'], ['--form','json','show','a'],
    ['test','[foo]','foo'], ['test','a','--tokens','not-json'],
    ['strings','a','--depth','0'], ['strings','a','--limit','-1'],
    ['strings','a','--mode','wrong'], ['somestrings','a','--mode','acyclic','--depth','2'],
    ['morestrings','a','0'], ['morestrings','a','2','--depth','3'],
    ['show','a','--format','bad'], ['show','a','--type','bad'],
    ['show','a','--type','pfa','--format','jflap'], ['show','a','--type','nfa','--trim'],
    ['normalize','a','--quiet'], ['dfa2gv','a','--format','json'],
    ['random_re','--length','0'], ['random_re','--seed','abc'],
) {
    my ($status,$out,$err)=cli('',@$args);
    is($status,2,"usage/input error @$args"); is($out,'','error keeps stdout clean');
    like($err,qr/^fash: /,'consistent error prefix');
    unlike($err,qr/ at \S+ line \d+/,'no implementation stack in ordinary errors');
}
my $injected = File::Spec->catfile($dir,'injected');
my ($bad)=cli('', 'normalize', 'a");open(F,">'.$injected.'");print F "executed";#');
is($bad,2,'program-like expression is rejected'); ok(!-e $injected,'arguments never execute as Perl');
my $saved = File::Spec->catfile($dir,'saved.dat');
successful('', ['savedfa','a','--output',$saved], qr/^$/, 'save explicit file');
ok(-s $saved,'saved DFA exists');
my ($exists,undef,$exists_error)=cli('', 'savedfa','b','--output',$saved);
is($exists,3,'overwrite is an operation error'); like($exists_error,qr/--force/,'overwrite remedy');
successful('', ['savedfa','b','--output',$saved,'--force'], qr/^$/, 'explicit overwrite');
my ($io,undef,$io_error)=cli('', 'savedfa','a','--output',File::Spec->catfile($dir,'absent','file'));
is($io,3,'write error status'); like($io_error,qr/^fash:/,'write error prefix');

my $jff = File::Spec->catfile($dir,'example.jff');
my $xml=successful('', ['dfa2jflap','ab*'], qr/<read>/, 'JFLAP export');
open my $fh,'>:raw',$jff or die $!; print $fh $xml; close $fh;
successful('', ['test','--input-format','jflap',$jff,'abbb'], qr/\(\+\)/,'test JFLAP file');
successful($xml, ['show','--input-format','jflap','-','--type','nfa','--format','json'], qr/\"states\"/, 'JFLAP stdin import');
successful('', ['compare','--input-format','jflap',$jff,$jff], qr/Yes/,'compare JFLAP files');
successful('', ['show','--input-format','jflap',$jff,'--format','jflap'], qr/<structure>/,'JFLAP round trip');
successful('', ['dfa2jflap','[foo]','--expand-labels'], qr/<read>f<\/read>/,'explicit token expansion');
my ($needs)=cli('', 'dfa2jflap','[foo]'); is($needs,3,'token export requires explicit mapping');
my ($missing)=cli('', 'show','--input-format','jflap',File::Spec->catfile($dir,'missing.jff'));
is($missing,2,'missing import is an input error');
for my $command (FLAT::CLI->commands) { ok($exercised{$command},"advertised command exercised: $command") }
done_testing;
