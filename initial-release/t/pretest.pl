#!/usr/bin/env perl

#
# Brett D. Estrade <estrabd@mailcan.com>
#
# NFA to DFA driver
#
# $Revision: 1.5 $ $Date: 2005/10/12 07:06:38 $ $Author: perlfan $

$^W++;
$|++;

use strict;
use Data::Dumper;
use lib qw(../);
use PRE;
use PFA;
use NFA;
use DFA;

if (defined($ARGV[0])) {
  my $test = $ARGV[0];
  chomp($test);
  my $pre = PRE->new();
  print STDERR "$test\n";
  $pre->trace_on();
  $pre->set_pre($test);
  $pre->parse();
  my $pfa1 = $pre->to_pfa();
  $pfa1->number_nodes();
  my $nfa1 = $pfa1->to_nfa();
  $nfa1->number_states();
  my $dfa1 = $pre->to_pfa()->to_nfa()->to_dfa();
  my @removed = $dfa1->minimize();
  $dfa1->number_states();
  #print STDERR $pfa1->info();
  #print STDERR $nfa1->info();
  print STDERR $dfa1->info();
  print STDOUT $dfa1->to_gdl();
} else {
  while (<DATA>) {
    my $test = $_;
    chomp($test);
    my $pre = PRE->new();
    print "$test\n";
    $pre->trace_on();
    $pre->set_pre($test);
    $pre->parse();
  }
}
__DATA__
ad|cb|(d*|)
((ab)*(bc)*)*
(a*|(b*|c*)*)bc*
(a|b|c|d|e|)*
ea*b*c*e*d*e
e|((b||((a|b)|c))|b)
(((c*)**)b)*
(a(b(dc*)*)*)
a***
