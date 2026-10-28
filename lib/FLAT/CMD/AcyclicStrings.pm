package FLAT::CMD::AcyclicStrings;
use strict;
use warnings;
use Exporter 'import';
use FLAT::CLI;
our @EXPORT = qw(as_strings);

sub as_strings {
    my ($expression) = @_;
    return FLAT::CLI->run('somestrings', '--limit', '0',
                         defined $expression ? $expression : '-');
}
1;
