package FLAT::CMD::DFTStrings;
use strict;
use warnings;
use Exporter 'import';
use FLAT::CLI;
our @EXPORT = qw(as_strings);

sub as_strings {
    my ($expression, $depth) = @_;
    return FLAT::CLI->run('morestrings', '--limit', '0',
                         defined $expression ? $expression : '-',
                         defined $depth ? $depth : 1);
}
1;
