use strict;
use warnings;
use utf8;
use Test::More;
use Scalar::Util qw(refaddr weaken);
use FLAT;
use FLAT::Regex::WithExtraOps;
use FLAT::Symbol::Token;
use FLAT::Regex::Lexer;
use FLAT::Regex::ParseError;

binmode Test::More->builder->output, ':encoding(UTF-8)';
binmode Test::More->builder->failure_output, ':encoding(UTF-8)';
ok(!exists $INC{'Parse/RecDescent.pm'},'normal library load does not load RecDescent');
my $plain=FLAT::Regex::Parser->new(qw(alt concat star));
my $extended=FLAT::Regex::WithExtraOps->_parser;
for my $case (
 ['ab+c','ab+c'],['a|b','a+b'],['a&bc+d','a&bc+d'],
 ['a&b+c&d','a&b+c&d'],['~ab&c','~ab&c'],['a&~bc','a&~bc'],
 ['a(~b)','a(~b)'],['(a+b)*c','(a+b)*c'],['a(bc)','abc'],
 ['[foo][ ][#][]','[foo][ ][#][]'],['[猫]','[猫]'],['[[x]','[[x]'],
 ['[\\]','[\\]'],['#',' #'],['[]','[]']) {
    my ($text,$normalized)=@$case; $normalized =~ s/^ //;
    is(FLAT::Regex::WithExtraOps->new($text)->as_string,$normalized,"normalize $text");
}
for my $bad ('',' ','a++b','a**','a+*','()','(a','a)','[foo','a?','a~b','~~a','~','猫','a&','&a','a|') {
    my $result=$extended->parse($bad);
    is($result,undef,'malformed expression rejected');
    isa_ok($extended->error,'FLAT::Regex::ParseError');
}
is($plain->parse('a&b'),undef,'ordinary grammar excludes shuffle');
is($plain->parse('~a'),undef,'ordinary grammar excludes negation');
my $op=$extended->parse("a+\n  [猫]");
is($extended->error,undef,'successful reuse clears last error');
is_deeply($op->source_span,{start=>0,end=>8,line=>1,column=>1,end_line=>2,end_column=>6},'root source span uses characters and exclusive end');
my @children=$op->members;
is_deeply($children[1]->source_span,{start=>5,end=>8,line=>2,column=>3,end_line=>2,end_column=>6},'Unicode leaf location');
my $span=$op->source_span; $span->{start}=999;
is($op->source_span->{start},0,'span accessor returns a copy');
my $group=FLAT::Regex->new(' ( a ) ')->op;
is_deeply($group->source_span,{start=>1,end=>6,line=>1,column=>2,end_line=>1,end_column=>7},'group extends root span');
my $failed=eval { FLAT::Regex->new("a+\n)"); 1 };
ok(!$failed,'public constructor throws');
my $error=$@;
isa_ok($error,'FLAT::Regex::ParseError');
is($error->offset,3,'error character offset'); is($error->line,2,'error line'); is($error->column,1,'error column');
like("$error",qr/line 2, column 1.*expected an atom/s,'error stringification');
my $errorhash=$error->as_hash; $errorhash->{offset}=999;
is($error->offset,3,'error hash accessor is a copy');
my $lexer=FLAT::Regex::Lexer->new;
my $tokens=$lexer->tokenize(" [a\nb] + [] # [#]");
is_deeply([map { $_->{type} } @$tokens],[qw(atom + atom atom atom eof)],'lexer token kinds');
is_deeply([map { $_->{value} } @$tokens[0,2,3,4]],["a\nb",'',undef,'#'],'epsilon, empty language and literals distinct');
is($tokens->[1]{line},2,'lexer tracks newline inside literal');
my $limited=FLAT::Regex::Parser->new(max_depth=>2,max_length=>20,max_token_length=>3);
ok(defined $limited->parse('((a))'),'nesting limit inclusive');
is($limited->parse('(((a)))'),undef,'nesting limit enforced');
like($limited->error->message,qr/max_depth/,'depth diagnostic');
is($limited->parse('[abcd]'),undef,'token length limited');
like($limited->error->message,qr/max_token_length/,'token length diagnostic');
is($limited->parse('a'x21),undef,'expression length limited');
like($limited->error->message,qr/max_length/,'input length diagnostic');
is($limited->parse(undef),undef,'undefined input rejected');
is($limited->parse({}),undef,'reference input rejected');
for my $args ([max_depth=>0],[max_length=>0],[operators=>'alt'],['unknown'],[max_depth=>2,unknown=>1]) {
    ok(!eval { FLAT::Regex::Parser->new(@$args); 1 },'invalid parser configuration rejected');
}
my $deep=FLAT::Regex::Parser->new(max_depth=>128);
my @warnings;
{ local $SIG{__WARN__}=sub {push @warnings,@_}; ok(defined $deep->parse('('x110 .'a'.')'x110),'deep valid group parses'); }
is_deeply(\@warnings,[],'bounded deep parsing emits no recursion warnings');
my $payload={};
my $symbol=FLAT::Symbol::Token->new(key=>'open',label=>'a+b*',payload=>$payload);
my $atom=FLAT::Regex->atom($symbol);
is($atom->as_string,'[open]','AST serializes matching key, not display syntax');
is(refaddr($atom->op->symbol),refaddr($symbol),'AST retains original token');
is($atom->op->key,'open','atom key accessor');
is($atom->op->source_span,undef,'programmatic atom has no source location');
my $plan=$atom->concat(FLAT::Regex->atom('close'));
ok($plan->contains_tokens([$symbol,'close']),'programmatic token AST matches');
my $dfa=$plan->as_pfa->as_dfa->as_min_dfa;
is(refaddr($dfa->symbol('open')->payload),refaddr($payload),'AST-to-FA conversion retains payload identity');
is(refaddr($plan->reverse->as_nfa->symbol('open')),refaddr($symbol),'AST reversal retains symbol');
is(FLAT::Regex->atom('#')->as_string,'[#]','literal hash factory distinct from empty language');
is(FLAT::Regex->epsilon->as_string,'[]','epsilon factory');
is(FLAT::Regex->empty->as_string,'#','empty language factory');
is(FLAT::Regex->atom('猫')->as_string,'[猫]','Unicode key serialization is parseable');
ok(FLAT::Regex->new(FLAT::Regex->atom('猫')->as_string)->contains_tokens(['猫']),'Unicode formal text round trip');
my $unprintable=FLAT::Regex->atom(']');
ok(!eval { $unprintable->as_string; 1 },'unrepresentable closing bracket fails explicitly');
ok($unprintable->contains_tokens([']']),'unrepresentable text key still works programmatically');
for my $code (
 sub { FLAT::Regex::Op::atomic->new() },
 sub { FLAT::Regex::Op::atomic->new('a','b') },
 sub { FLAT::Regex::Op::atomic->new({}) },
 sub { FLAT::Regex::Op::star->new('a') },
 sub { FLAT::Regex::Op::concat->new() },
 sub { FLAT::Regex::Op::alt->new($atom->op,{}) },
 sub { FLAT::Regex->from_op([]) }) {
    ok(!eval { $code->(); 1 },'invalid AST construction rejected');
}
my $current_tree=$extended->parse_or_die('a+b&c');
is($current_tree->as_string(0),'a+b&c','default preserves modern precedence');
my $current_pre=FLAT::Regex::WithExtraOps->from_op($current_tree);
ok(!$current_pre->contains_tokens(['a','c']),'modern precedence rejects ac');
ok($current_pre->contains_tokens(['a']),'modern precedence accepts a');
my $grouped=FLAT::Regex::WithExtraOps->new('(a+b)&c');
ok($grouped->contains_tokens(['a','c']),'explicit grouping selects alternative order');
ok(!$grouped->contains_tokens(['a']),'grouped alternative requires c');
my $weak;
{ my $node=$plain->parse('a'); $weak=$node; weaken($weak); }
is($weak,undef,'source metadata does not retain released nodes');
done_testing;
