use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir tempfile);
use File::Spec;
use IPC::Open3;
use ExtUtils::Packlist;
use FLAT::CLI;
use FLAT::CLI::Completion;

plan skip_all => 'completion installation is not enabled on native Windows' if $^O eq 'MSWin32';
my $dir = tempdir(CLEANUP=>1);
my $path = File::Spec->catfile($dir,'fash.bash');
open my $script,'>',$path or die $!;
my $generated = FLAT::CLI::Completion->bash;
print $script $generated; close $script;
is($generated,FLAT::CLI::Completion->bash,'completion generation is deterministic');
for my $command (FLAT::CLI->commands) {
    like($generated,qr/\Q$command\E/,"registry command appears: $command");
}
my $meta = FLAT::CLI->completion_metadata;
for my $command (FLAT::CLI->commands) {
    for my $option (@{$meta->{options}{$command}}) {
        like($generated,qr/\Q$option\E/,"registry option appears: $command $option");
    }
}
my $stage = File::Spec->catdir($dir,'stage');
my $bindir = File::Spec->catdir($stage,'opt','flat','bin');
my $packfile = File::Spec->catfile($dir,'.packlist');
ExtUtils::Packlist->new->write($packfile);
my $installed=FLAT::CLI::Completion->install(bindir=>$bindir,destdir=>$stage,packlist=>$packfile);
is($installed,File::Spec->catfile($stage,'opt','flat','share','bash-completion','completions','fash'),
   'default completion follows the staged executable prefix');
ok(-s $installed,'completion installed');
my $pack=ExtUtils::Packlist->new($packfile);
ok(exists $pack->{'/opt/flat/share/bash-completion/completions/fash'},'packlist records logical path without staging root');
my $override=FLAT::CLI::Completion->install(directory=>'/custom/completions',destdir=>$stage);
is($override,File::Spec->catfile($stage,'custom','completions','fash'),'absolute override stays inside DESTDIR');
is(FLAT::CLI::Completion->install(directory=>'none'),undef,'explicit opt-out');
eval { FLAT::CLI::Completion->install(directory=>'relative') };
like($@,qr/must be absolute/,'relative installation overrides are rejected');

my $bash;
for my $entry (File::Spec->path) {
    my $candidate=File::Spec->catfile($entry,'bash');
    if (-x $candidate) { $bash=$candidate; last }
}
SKIP: {
    skip 'Bash is not installed', 26 unless $bash;
    is(system($bash,'-n',$path),0,'generated script passes bash -n');
    sub complete_words {
        my (@words)=@_;
        my ($out)=tempfile(DIR=>$dir); my ($err)=tempfile(DIR=>$dir);
        my $code = 'source "$1"; shift; COMP_WORDS=("$@"); COMP_CWORD=$((${#COMP_WORDS[@]}-1)); _fash; printf "%s\n" "${COMPREPLY[@]}"';
        my $pid=open3(my $in,'>&'.fileno($out),'>&'.fileno($err),$bash,'--noprofile','--norc','-c',$code,'--',$path,@words);
        close $in; waitpid $pid,0;
        die 'completion shell failed' if $?;
        seek $out,0,0; local $/; my $text=<$out> // '';
        return [sort grep length, split /\n/,$text];
    }
    is_deeply(complete_words('fash','comp'),[qw(compare complement completion)],'command prefix');
    is_deeply(complete_words('fash','--v'),['--version'],'global option prefix');
    is_deeply(complete_words('fash','help','str'),['strings'],'help command prefix');
    is_deeply(complete_words('fash','completion',''),['bash'],'supported completion shell');
    is_deeply(complete_words('fash','show','a','--fo'),['--format'],'applicable option');
    is_deeply(complete_words('fash','normalize','a','--fo'),[],'inapplicable option omitted');
    is_deeply(complete_words('fash','dfa2gv','a','--fo'),[],'alias format override omitted');
    is_deeply(complete_words('fash','show','a','--format','j'),[qw(jflap json)],'format values');
    is_deeply(complete_words('fash','show','a','--type','d'),['dfa'],'type values');
    is_deeply(complete_words('fash','strings','a','--mode','d'),['depth'],'mode values');
    is_deeply(complete_words('fash','show','a','--format=js'),['--format=json'],'equals-style option');
    is_deeply(complete_words('fash','show','a','--format','=','js'),['json'],'Bash wordbreak equals style');
    is_deeply(complete_words('fash','--type','dfa','show','a','--format','js'),['json'],'options before command');
    is_deeply(complete_words('fash','test','a','--','--q'),[],'end of options respected');
    is_deeply(complete_words('fash','test','a','word'),[],'word input is not guessed');
    is_deeply(complete_words('fash','strings','a','--depth',''),[],'numeric input is not guessed');
    is_deeply(complete_words('fash','test','a','-'),[qw(--batch --help --input-format --quiet --tokens --version -b -h -q)],'short aliases included');
    my $file=File::Spec->catfile($dir,'a model.jff');
    open my $fh,'>',$file or die $!; close $fh;
    my $prefix=File::Spec->catfile($dir,'a m');
    is_deeply(complete_words('fash','savedfa','a','--output',$prefix),[$file],'output filename with spaces');
    is_deeply(complete_words('fash','show','--input-format','jflap',$prefix),[$file],'JFLAP input filename');
    is_deeply(complete_words('fash','show','--input-format=jflap',$prefix),[$file],'equals-style input format');
    is_deeply(complete_words('fash','show','--input-format','=','jflap',$prefix),[$file],'wordbreak input format');
    is_deeply(complete_words('fash','test','--input-format','jflap',$file,$prefix),[],'test words are not completed as JFLAP files');
    is_deeply(complete_words('fash','compare','--input-format','jflap',$file,$prefix),[$file],'second comparison input');
    my $marker=File::Spec->catfile($dir,'executed');
    is_deeply(complete_words('fash','show','$(touch '.$marker.')','--format','js'),['json'],'expression text is not evaluated');
    ok(!-e $marker,'completion never executes expression text');
}
done_testing;
