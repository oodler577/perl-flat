#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::DFA;
use FLAT::Regex::WithExtraOps;

my $dfa = FLAT::Regex::WithExtraOps->new($ARGV[0])->as_pfa->as_nfa->as_dfa->as_min_dfa->trim_sinks;

my %nodes = $dfa->as_node_list();

my %dflabel       = ();    # "global" lookup table for dflable
my %backtracked   = (); # "global" lookup table for backtracked edges
my %low           = (); # "global" lookup table for low
my $lastDFLabel   = 0;
my $recurse_level = 0; # tracks recurse level
my @string        = ();
# anonymous, recursive function

&acyclic($dfa->get_starting());

# this function finds all acyclic paths in the dfa for each symbol!!
sub acyclic {                            
  my $startNode = shift;
  $recurse_level++; # <- tracker
# tree edge detection
  if (!exists($dflabel{$startNode})) {
    $dflabel{$startNode} = ++$lastDFLabel;  # the order inwhich this link was explored
    $low{$startNode} = $lastDFLabel;
    $backtracked{$startNode} = 0;           # marks this node as visited before - for cross edge detection
    foreach my $adjacent (keys(%{$nodes{$startNode}})) {
      if (!exists($dflabel{$adjacent})) {      # initial tree edge
        foreach my $symbol (@{$nodes{$startNode}{$adjacent}}) {
	  push(@string,$symbol);
          acyclic($adjacent);
          $backtracked{$adjacent}++;  # <- track backtracked nodes
	  if ($low{$startNode} > $low{$adjacent}) {
	    $low{$startNode} = $low{$adjacent};
	  }	
	  if ($dfa->is_accepting($adjacent)) {
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
  $recurse_level--; # <- tracker
  return;     
};
