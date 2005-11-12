use Test::More 'no_plan';
use FLAT::Regex;

use Data::Dumper;

my $reg;

is( "" . FLAT::Regex->new( "(((a)bc)def)ghi" ),
    "abcdefghi",
    "Collapse parens for concatenation" );

is( "" . FLAT::Regex->new( "(((a)+b+c)+d+e+f)+g+h+i" ),
    "a+b+c+d+e+f+g+h+i",
    "Collapse parens for alternation" );
    
is( "" . FLAT::Regex->new( "(a+(b+(cd)))*" ),
    "(a+b+cd)*",
    "Parens kept for precedence" );



for ( ")ab",  "a(bc(d)", "ab)cd(ef", "a+b+", "a++b", "+a", "h**", "a+*" ) {
    eval { FLAT::Regex->new($_) };
    ok( $@,
        "Parse error caught: $_" );
}


$reg = FLAT::Regex->new( "abc+def+ghi*+(a+b)*" );
is( "" . $reg,
    "" . $reg->reverse->reverse,
    "Reversal operation idempotent" );

