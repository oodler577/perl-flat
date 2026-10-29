#!/usr/bin/env perl

# $Revision: 1.17 $ $Date: 2005/03/23 19:22:55 $ $Author: estrabd $

$^W++;
use strict;
use NFA;
use DFA;
use RE; 
use Cwd;
use constant VERSION => '$Revision: 1.17 $ $Date: 2005/03/23 19:22:55 $';

# untested xp solution to getting interactive input on windows.
if($^O eq 'MSWin32') {
    open(TTY, "CON") or die $!;
} else {
    open(TTY, "</dev/tty") or die $!;
}    

print STDERR VERSION;
print STDERR "\nWelcome to a f\@sh, shell for finite automata enthusiasts\n\n";
print STDERR "Type 'help' to get started...\n";

my $NFA1 = NFA->new();
my $DFA1 = DFA->new();
my $RE1  = RE->new();
my $CWD  = getcwd();

my $in = undef;
while (1) {
  print STDERR "f\@sh>";
  $in = <TTY>;
  dispatch($in);
}

sub dispatch {
  my $in = shift;
  chomp ($in);
  if ($in =~ m/\?|help/) {
    help();
  } elsif ($in =~ m/^\s*(!)\s*(.*)\s*$/i) {
    system("$2");
  } elsif ($in =~ m/^\s*(nfa2dfa)\s*$/i) {
    nfa2dfa();
  } elsif ($in =~ m/^\s*(re2dfa)\s*$/i) {
    re2dfa();
  } elsif ($in =~ m/^\s*(ls)\s*$/i) {
    system("ls");
  } elsif ($in =~ m/^\s*(pwd)\s*$/i) {
    print STDERR "$CWD\n";
  } elsif ($in =~ m/^\s*(cd)\s*(.*)\s*$/i) {
    cd($2);
  } elsif ($in =~ m/^\s*(quit)\s*$/i) {
    quit();
  } elsif ($in =~ m/^\s*(clear)\s*$/i) {
    system('clear');
  } elsif ($in =~ m/^\s*(info)\s*(.*)\s*$/i) {
    info($2);
  } elsif ($in =~ m/^\s*(loadnfa)\s*(.*)\s*$/i) {
    loadnfa($2);
  } elsif ($in =~ m/^\s*(loaddfa)\s*(.*)\s*$/i) {
    loaddfa($2);
  } elsif ($in =~ m/^\s*(newre)\s*(.*)\s*$/i) {
    newre($2);
  } elsif ($in =~ m/^\s*(savenfa)\s*(.*)\s*$/i) {
    savenfa($2);
  } elsif ($in =~ m/^\s*(savedfa)\s*(.*)\s*$/i) {
    savedfa($2);
  } elsif ($in =~ m/^\s*(unload)\s*(.*)\s*$/) {
    unload($2);
  } elsif ($in =~ m/^\s*(version)\s*$/) {
    print STDERR VERSION,"\n";;
  } elsif ($in =~ m/^\s*(test)\s*(.*)\s*$/) {
    if ($DFA1->is_valid($2) == 1) {
      print STDERR "'$2' is valid\n";
    } else {
      print STDERR "'$2' is not valid!\n";    
    }
  } elsif ($in !~ m/^$/) {
    print STDERR "Unrecognized command\n";
  }
}

sub cd {
  my $dir = shift;
  if ($dir =~ m/^$/) {
    print STDERR "What directory?";
    $dir = <TTY>;
  }
  chomp($dir);
  if (-d $dir) {
    chdir($dir);
    $CWD = getcwd();
  } else {
    print STDERR "Can't change to $dir!\n";
  }
}

sub savedfa {
  my $file = shift;
  if ($file =~ m/^$/) {
    print STDERR "Save dfa as?";
    $file = <TTY>;
  }
  chomp($file);
  if (defined($DFA1)) {
    $DFA1->to_file($file);
  } else {
    print STDERR "no dfa loaded\n";
  }
}

sub savenfa {
  my $file = shift;
  if ($file =~ m/^$/) {
    print STDERR "Save nfa as?";
    $file = <TTY>;
  }
  chomp($file);
  if (defined($NFA1)) {
    $NFA1->to_file($file);
  } else {
    print STDERR "no nfa loaded\n";
  }
}

sub nfa2dfa {
  if (defined($NFA1)) {
    $DFA1 = $NFA1->to_dfa();
  }
}

sub re2dfa {
  if (defined($RE1)) {
    $DFA1 = $RE1->to_dfa();
  }
}

sub loaddfa {
  my $file = shift;
  if ($file =~ m/^$/) {
    print STDERR "file?:";
    $file = <TTY>;
  }
  chomp($file);
  $DFA1 = DFA->new();
  $DFA1->load_file($file);
}

sub loadnfa {
  my $file = shift;
  if ($file =~ m/^$/) {
    print STDERR "file?\n";
    $file = <TTY>;
  }
  chomp($file);
  $NFA1 = NFA->new();
  $NFA1->load_file($file);
}

sub newre {
  my $re = shift;
  chomp($re);
  $RE1 = RE->new();
  $RE1->set_re($re);
}

sub info {
  my $type = shift;
  if ($type =~ m/^$/) {
    print STDERR "nfa or dfa?\n";
    $type = <TTY>;
  }  
  chomp($type);
  if ($type eq 'dfa') {
    print STDERR $DFA1->info();
  } elsif ($type eq 'nfa') {
    print STDERR $NFA1->info();
  } elsif ($type eq 're') {
    print STDERR $RE1->get_re(),"\n";  
  } else {
    print STDERR "no finite automata loaded\n";
  }
}

sub unload {
  my $type = shift;
  if ($type eq 'dfa') {
    $DFA1 = DFA->new();
  } elsif ($type eq 'nfa') {
    $NFA1 = NFA->new();  
  }
}

sub help {
   print STDERR "\t! cmd               - execute shell command\n";
   print STDERR "\tadd[dfa|nfa]state*  - adds state to current dfa/nfa\n";
   print STDERR "\tadd[dfa|nfa]trans*  - adds transition dfa/nfa\n";
   print STDERR "\tadd[dfa|nfa]symbol* - add symbol to current fa\n";
   print STDERR "\taddetrans*          - add epsilon transition to nfa\n";   
   print STDERR "\tcd dir              - change to dir\n";
   print STDERR "\tclear               - clears display\n";
   print STDERR "\tinfo [nfa|dfa|re]   - shows nfa|dfa|re info\n";
   print STDERR "\tloadnfa filename    - load nfa from file\n";
   print STDERR "\tloaddfa filename    - load dfa from file\n";
   print STDERR "\tls                  - list directory contents\n";
   print STDERR "\tquit                - quit, you quitter :)\n";
   print STDERR "\tnewnfa*             - creates blank nfa canvas\n";
   print STDERR "\tnewdfa*             - creates blank dfa canvas\n";
   print STDERR "\tnewre <regex>       - creates a new regular expression\n";
   print STDERR "\tnfa2dfa             - converts nfa to dfa\n";
   print STDERR "\tre2dfa              - converts re to dfa\n";
   print STDERR "\tpwd                 - show present workding directory\n";
   print STDERR "\tremovestate*        - unloads current dfa\n";
   print STDERR "\tremovetrans*        - unloads current dfa\n";
   print STDERR "\tsavenfa file*       - saves nfa to file\n";
   print STDERR "\tsavedfa file*       - saves dfa to file\n";
   print STDERR "\tunload [dfa|nfa]    - unloads current dfa\n";
   print STDERR "\tversion             - shows CVS info\n";
   print STDERR "NOTE: *not yet implemented\n";
}

sub quit {
  die "...later, gator\n";
}
