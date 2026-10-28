use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use FLAT::CLI::Completion;
my %args;
GetOptions(\%args, 'bindir=s', 'directory=s', 'destdir=s', 'packlist=s') or die "invalid installation options\n";
my $path = FLAT::CLI::Completion->install(%args);
print defined $path ? "Installing Bash completion $path\n" : "Skipping Bash completion installation\n";
