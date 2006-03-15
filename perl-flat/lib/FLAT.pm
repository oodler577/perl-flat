package FLAT;
use FLAT::Regex;
use Carp;

use vars '$VERSION';
$VERSION = 0.01;

## let subclasses implement a minimal set of closure properties.
## they can override these with more efficient versions if they like.

sub as_dfa {
    $_[0]->as_nfa->determinize;
}

sub as_min_dfa {
    $_[0]->as_dfa->minimize;
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

1;
