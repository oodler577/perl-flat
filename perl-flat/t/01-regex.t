use Test::More 'no_plan';
use FLAT::Regex;

use Data::Dumper;

my $reg;

sub regex { FLAT::Regex->new(@_) }

is( "" . regex( "(((a)bc)def)ghi" ),
    "abcdefghi",
    "Collapse parens for concatenation" );

is( "" . regex( "(((a)+b+c)+d+e+f)+g+h+i" ),
    "a+b+c+d+e+f+g+h+i",
    "Collapse parens for alternation" );
    
is( "" . regex( "(a+(b+(cd)))*" ),
    "(a+b+cd)*",
    "Parens kept for precedence" );

is( "". regex("#"),
    "#",
    "Null regex" );

is( "". regex("[]"),
    "[]",
    "epsilon" );


for ( ")ab",  "a(bc(d)", "ab)cd(ef", "a+b+", "a++b", "+a", "h**", "a+*" ) {
    eval { regex($_) };
    ok( $@,
        "Parse error caught: $_" );
}


$reg = regex( "abc+def+ghi*+(a+b)*" );
is( "" . $reg,
    "" . $reg->reverse->reverse,
    "Reversal operation idempotent" );

#####

ok( regex("#")->is_empty,
    "is_empty (atomic)" );
    
ok( regex("a#a")->is_empty,
    "is_empty (concatenation)" );

ok( ! regex("aa")->is_empty,
    "is_empty (concatenation)" );

ok( ! regex("#*")->is_empty,
    "is_empty (star)" );

ok( ! regex("#+b")->is_empty,
    "is_empty (alternation)" );

ok( regex("#+#")->is_empty,
    "is_empty (alternation)" );


ok( regex("a")->is_finite,
    "is_finite (atomic)" );

ok( regex("#")->is_finite,
    "is_finite (atomic)" );

ok( regex("#*")->is_finite,
    "is_finite (star)" );

ok( regex("[]*")->is_finite,
    "is_finite (star)" );

ok( regex("([]+ [][])*")->is_finite,
    "is_finite (star)" );

ok( ! regex("a*")->is_finite,
    "is_finite (star)" );

ok( regex("a+b")->is_finite,
    "is_finite (alternation)" );

ok( ! regex("a+a*")->is_finite,
    "is_finite (alternation)" );
    
ok( regex("aa")->is_finite,
    "is_finite (concatenation)" );

ok( ! regex("a*a")->is_finite,
    "is_finite (concatenation)" );
