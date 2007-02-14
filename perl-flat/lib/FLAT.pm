package FLAT;
use FLAT::Regex;
use FLAT::NFA;
use FLAT::DFA;
use Carp;

use vars '$VERSION';
$VERSION = 0.01;

## let subclasses implement a minimal set of closure properties.
## they can override these with more efficient versions if they like.

sub as_dfa {
    $_[0]->as_nfa->as_dfa;
}

sub as_min_dfa {
    $_[0]->as_dfa->as_min_dfa;
}

sub is_infinite {
    ! $_[0]->is_finite;
}

sub star {
    $_[0]->kleene
}

sub difference {
    $_[0]->intersect( $_[1]->complement );
}

sub symdiff {
    my $self = shift;
    return $self if not @_;
    my $next = shift()->symdiff(@_);
    ( $self->difference($next) )->union( $next->difference($self) );
}

sub equals {
    $_[0]->symdiff($_[1])->is_empty
}

sub is_subset_of {
    $_[0]->difference($_[1])->is_empty
}


BEGIN {
    for my $method (qw[ as_nfa as_regex union intersect complement concat
                        kleene reverse is_empty is_finite ])
    {
        no strict 'refs';
        *$method = sub {
            my $pkg = ref $_[0] || $_[0];
            carp "$pkg does not (yet) implement $method";
        };
    }
}

# Support for perl one liners - like what CPAN.pm uses #<- should move all to another file
use base 'Exporter'; #instead of: use Exporter (); @ISA = 'Exporter';
use vars qw(@EXPORT $AUTOLOAD);

@EXPORT = qw(compare 
             dump  
	     dfa2dot 
	     nfa2dot 
	     pfa2dot 
	     random_pre 
	     random_re
	     help
	     );

# Todo: validate, test (string against re), validate (re), 
#       alternate (give re, list some alternates), getstrings (gen strings give re)	     

sub AUTOLOAD {
    my($l) = $AUTOLOAD;
    $l =~ s/.*:://;
    my(%EXPORT);
    @EXPORT{@EXPORT} = '';
    if (exists $EXPORT{$l}){
	FLAT::OneLiners->$l(@_);
    }
}

package FLAT::OneLiners;

sub help {
print <<END
%perl -MFLAT -e
		"compare  're1','re2'"
		"dump     're1'" 
		"dfa2dot  're1'" 
		"nfa2dot  're1'" 
		"pfa2dot  're1'" 
		random_pre 
		random_re
		help
	To Do:
	        "getstrings 're1' [opts...]" # given regex, pump strings based on options
		"variations 're1' [opts...]" # given regex will provide equivalents
END
}

# dumps parse tree
# Usage:
# perl -MFLAT -e "dump('a&b&c&d*e*')"
sub dump {
  shift;
  use FLAT::Regex::WithExtraOps;
  use Data::Dumper;
  my $PRE = FLAT::Regex::WithExtraOps->new(shift);
  print Dumper($PRE);
}

# dumps graphviz notation
# Usage:
# perl -MFLAT -e "dfa2dot('a&b&c&d*e*')"
sub dfa2dot {
  shift;  
  use FLAT::Regex::WithExtraOps;
  use FLAT::DFA;
  my $DFA1 = FLAT::Regex::WithExtraOps->new(shift)->as_nfa()->as_dfa->as_min_dfa();
  print $DFA1->as_graphviz;
}

# dumps graphviz notation
# Usage:
# perl -MFLAT -e "nfa2dot('a&b&c&d*e*')"
sub nfa2dot {
  shift;  
  use FLAT::Regex::WithExtraOps;
  use FLAT::NFA;
  my $NFA1 = FLAT::Regex::WithExtraOps->new(shift)->as_nfa();
  print $NFA1->as_graphviz;
}

# dumps graphviz notation
# Usage:
# perl -MFLAT -e "pfa2dot('a&b&c&d*e*')"
sub pfa2dot {
  shift;  
  use FLAT::Regex::WithExtraOps;
  use FLAT::PFA;
  my $PFA1 = FLAT::Regex::WithExtraOps->new(shift)->as_pfa();
  print $PFA1->as_graphviz;
}

# compares 2 give PREs
# Usage:
# perl -MFLAT -e "compare('a','a&b&c&d*e*')" #<-- no match, btw
sub compare {
  shift;
  use FLAT::Regex::WithExtraOps;
  use FLAT::DFA;
  use FLAT::PFA;
  my $PFA1 = FLAT::Regex::WithExtraOps->new(shift)->as_pfa();
  my $PFA2 = FLAT::Regex::WithExtraOps->new(shift)->as_pfa();
  my $DFA1 = $PFA1->as_nfa->as_min_dfa;
  my $DFA2 = $PFA2->as_nfa->as_min_dfa;
  if ($DFA1->equals($DFA2)) {
    print "Yes\n";
  } else {
    print "No\n";
  }
}

# prints random PRE
# Usage:
# perl -MFLAT -e random_pre
sub random_pre {
  shift;
  # skirt around deep recursion warning annoyance
  local $SIG{__WARN__} = sub { $_[0] =~ /^Deep recursion/ or warn $_[0] };
  srand $$;
  my %CMDLINEOPTS = ();
  # Percent chance of each operator occuring
  $CMDLINEOPTS{LENGTH} = 32;
  $CMDLINEOPTS{AND} = 10;
  $CMDLINEOPTS{OR} = 6;
  $CMDLINEOPTS{STAR} = 10;
  $CMDLINEOPTS{OPEN} = 5;
  $CMDLINEOPTS{CLOSE} = 0;
  $CMDLINEOPTS{n} = 1;

  my $getRandomChar = sub {
    my $ch = '';
    # Get a random character between 0 and 127.
    do {
      $ch = int(rand 2);
    } while ($ch !~ m/[a-zA-Z0-9]/);  
    return $ch;
  };

  my $getRandomRE = sub {
    my $str = '';
    my @closeparens = ();
    for (1..$CMDLINEOPTS{LENGTH}) {
      $str .= $getRandomChar->();  
      # % chance of an "or"
      if (int(rand 100) < $CMDLINEOPTS{OR}) {
	$str .= "|1";
      } elsif (int(rand 100) < $CMDLINEOPTS{AND}) {
	$str .= "&0";
      } elsif (int(rand 100) < $CMDLINEOPTS{STAR}) {
	$str .= "*1";     
      } elsif (int(rand 100) < $CMDLINEOPTS{OPEN}) {
	$str .= "(";
	push(@closeparens,'0101)');
      } elsif (int(rand 100) < $CMDLINEOPTS{CLOSE} && @closeparens) {
	$str .= pop(@closeparens);
      }
    }
    # empty out @closeparens if there are still some left
    if (@closeparens) {
      $str .= join('',@closeparens);  
    }
    return $str;
  };

  for (1..$CMDLINEOPTS{n}) {
    print $getRandomRE->(),"\n";  
  } 
}

# prints random RE (no & operator)
# Usage:
# perl -MFLAT -e random_re
sub random_re {
  shift;
  # skirt around deep recursion warning annoyance
  local $SIG{__WARN__} = sub { $_[0] =~ /^Deep recursion/ or warn $_[0] };
  srand $$;
  my %CMDLINEOPTS = ();
  # Percent chance of each operator occuring
  $CMDLINEOPTS{LENGTH} = 32;
  $CMDLINEOPTS{AND} = 0;   #<-- turns off & operator
  $CMDLINEOPTS{OR} = 6;
  $CMDLINEOPTS{STAR} = 10;
  $CMDLINEOPTS{OPEN} = 5;
  $CMDLINEOPTS{CLOSE} = 0;
  $CMDLINEOPTS{n} = 1;

  my $getRandomChar = sub {
    my $ch = '';
    # Get a random character between 0 and 127.
    do {
      $ch = int(rand 2);
    } while ($ch !~ m/[a-zA-Z0-9]/);  
    return $ch;
  };

  my $getRandomRE = sub {
    my $str = '';
    my @closeparens = ();
    for (1..$CMDLINEOPTS{LENGTH}) {
      $str .= $getRandomChar->();  
      # % chance of an "or"
      if (int(rand 100) < $CMDLINEOPTS{OR}) {
	$str .= "|1";
      } elsif (int(rand 100) < $CMDLINEOPTS{AND}) {
	$str .= "&0";
      } elsif (int(rand 100) < $CMDLINEOPTS{STAR}) {
	$str .= "*1";     
      } elsif (int(rand 100) < $CMDLINEOPTS{OPEN}) {
	$str .= "(";
	push(@closeparens,'0101)');
      } elsif (int(rand 100) < $CMDLINEOPTS{CLOSE} && @closeparens) {
	$str .= pop(@closeparens);
      }
    }
    # empty out @closeparens if there are still some left
    if (@closeparens) {
      $str .= join('',@closeparens);  
    }
    return $str;
  };

  for (1..$CMDLINEOPTS{n}) {
    print $getRandomRE->(),"\n";  
  } 
}

1;

__END__

=head1 NAME

FLAT - Formal Language & Automata Toolkit

=head1 SYNOPSIS

FLAT.pm is the base class of all regular language objects. For more
information, see other POD pages.

=head1 USAGE

All regular language objects in FLAT implement the following methods.
Specific regular language representations (regex, NFA, DFA) may implement
additional methods that are outlined in the repsective POD pages.

=head2 Conversions Among Representations

=over

=item $lang-E<gt>as_nfa

=item $lang-E<gt>as_dfa

=item $lang-E<gt>as_min_dfa

=item $lang-E<gt>as_regex

Returns an equivalent regular language to $lang in the desired
representation. Does not modify $lang (even if $lang is already in the
desired representation).

For more information on the specific algorithms used in these conversions,
see the POD pages for a specific representation.

=back

=head2 Closure Properties

=over

=item $lang1-E<gt>union($lang2, $lang3, ... )

=item $lang1-E<gt>intersect($lang2, $lang3, ... )

=item $lang1-E<gt>concat($lang2, $lang3, ... )

=item $lang1-E<gt>symdiff($lang2, $lang3, ... )

Returns a regular language object that is the union, intersection,
concatenation, or symmetric difference of $lang1 ... $langN, respectively.
The return value will have the same representation (regex, NFA, or DFA) 
as $lang1.

=item $lang1-E<gt>difference($lang2)

Returns a regular language object that is the set difference of $lang1 and
$lang2. Equivalent to

  $lang1->intersect($lang2->complement)

The return value will have the same representation (regex, NFA, or DFA) 
as $lang1.

=item $lang-E<gt>kleene

=item $lang-E<gt>star

Returns a regular language object for the Kleene star of $lang. The return
value will have the same representation (regex, NFA, or DFA) as $lang.

=item $lang-E<gt>complement

Returns a regular language object for the complement of $lang. The return
value will have the same representation (regex, NFA, or DFA) as $lang.

=item $lang-E<gt>reverse

Returns a regular language object for the stringwise reversal of $lang.
The return value will have the same representation (regex, NFA, or DFA)
as $lang.

=back

=head2 Decision Properties

=over

=item $lang-E<gt>is_finite

=item $lang-E<gt>is_infinite

Returns a boolean value indicating whether $lang represents a
finite/infinite language.

=item $lang-E<gt>is_empty

Returns a boolean value indicating whether $lang represents the empty
language.

=item $lang1-E<gt>equals($lang2)

Returns a boolean value indicating whether $lang1 and $lang2 are
representations of the same language.

=item $lang1-E<gt>is_subset_of($lang2)

Returns a boolean value indicating whether $lang1 is a subset of
$lang2.

=item $lang-E<gt>contains($string)

Returns a boolean value indicating whether $string is in the language
represented by $lang.

=back

=head1 AUTHORS & ACKNOWLEDGEMENTS

FLAT is written by Mike Rosulek E<lt>mike at mikero dot comE<gt> and Brett
Estrade E<lt>estradb at mailcan dot comE<gt>.

Initial version by Brett Estrade was work towards an MS thesis at the
University of Southern Mississippi.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
