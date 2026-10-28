use strict;
use warnings;
use Test::More;
use Pod::Simple::SimpleTree;
use FLAT::CLI;

for my $name (qw(perlflat perlfash)) {
    my $file="lib/$name.pod";
    ok(-f $file,"$name manual exists");
    my $parser=Pod::Simple::SimpleTree->new;
    $parser->parse_file($file);
    ok(!$parser->any_errata_seen,"$name POD parses without errors");
    open my $fh,'<',$file or die $!; local $/; my $pod=<$fh>;
    like($pod,qr/=head1 NAME\s+\Q$name\E\s+-/,"$name has a discoverable NAME");
    like($pod,qr/=head1 (?:SYNOPSIS|START HERE)/,"$name has an entry point");
    if ($name eq 'perlfash') {
        for my $command (FLAT::CLI->commands) {
            like($pod,qr/\b\Q$command\E\b/,"manual covers $command");
        }
        for my $number (1..6) { like($pod,qr/=head2 \Q$number\E\./,"plain-language proposal $number") }
        like($pod,qr/not implemented yet/,'planned capabilities are clearly marked');
    }
}
done_testing;
