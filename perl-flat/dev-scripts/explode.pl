#!/usr/bin/env perl -l

#
# To be implemented in the main module code soon 
# (minus not the store/retrieve stuff); that is here for the convenience of testing
#

#
# employs a recursive DFS based determination of all acyclic paths, which is 
# pretty darn efficient
#

use strict;

use lib qw(../lib);
use FLAT::DFA;
use FLAT::Regex::WithExtraOps;

my $dfa;
#example:
use Storable;

mkdir "dat" if (! -e "dat");

if (!-e "dat/$ARGV[0].dat") {
  $dfa = FLAT::Regex::WithExtraOps->new($ARGV[0])->as_pfa->as_nfa->as_dfa->as_min_dfa->trim_sinks;
  store $dfa, "dat/$ARGV[0].dat";
} else {
  print STDERR "dat/$ARGV[0].dat found.."; 
  $dfa = retrieve "dat/$ARGV[0].dat";
}

my %nodes = $dfa->as_node_list();

my %dflabel       = ();    # "global" lookup table for dflable
my %backtracked   = (); # "global" lookup table for backtracked edges
my %low           = (); # "global" lookup table for low
my $lastDFLabel   = 0;
my $recurse_level = 0; # tracks recurse level
my @string        = ();
# anonymous, recursive function

&acyclic($dfa->get_starting(),$dfa->get_accepting()); #<-- accepts start node and set of possible goals

# this function finds all acyclic paths in the dfa for each symbol!!
sub acyclic {                            
  my $startNode = shift;
  my @goalNodes = @_;
# tree edge detection
  if (!exists($dflabel{$startNode})) {
    $dflabel{$startNode} = ++$lastDFLabel;  # the order inwhich this link was explored
    foreach my $adjacent (keys(%{$nodes{$startNode}})) {
      if (!exists($dflabel{$adjacent})) {      # initial tree edge
        foreach my $symbol (@{$nodes{$startNode}{$adjacent}}) {
	  push(@string,$symbol);
          acyclic($adjacent,@goalNodes);
	  if ($dfa->array_is_subset([$adjacent],[@goalNodes])) { #< proof of concept
            printf("%s\n",join('',@string));
	  }
	  pop(@string);
        }
      }
    } 
  }
  # remove startNode entry to facilitate acyclic path determination
  delete($dflabel{$startNode});
  $lastDFLabel--;
  return;     
};
