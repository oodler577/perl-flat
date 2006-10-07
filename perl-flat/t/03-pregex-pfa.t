use Test::More tests => 2;
use FLAT;
use FLAT::NFA;
use FLAT::PFA;
use FLAT::DFA;
use FLAT::Regex::WithExtraOps;

# w&w
my $PFA1 = FLAT::Regex::WithExtraOps->new('abc&def')->as_pfa();
my $PFA2 = FLAT::Regex::WithExtraOps->new('a(b(c&def)+d(ef&bc))+d(ef&abc)')->as_pfa();

my $DFA1 = $PFA1->as_nfa->as_min_dfa;
my $DFA2 = $PFA2->as_nfa->as_min_dfa;

ok( ($DFA1->equals($DFA2)) );

# w&w*
$PFA1 = FLAT::Regex::WithExtraOps->new('abc&(def)*')->as_pfa();
$PFA2 = FLAT::Regex::WithExtraOps->new('(def)*(a(bc&(def)*)+d((efd)*ef&(abc))+d((efd)*&(abc))ef)')->as_pfa();

$DFA1 = $PFA1->as_nfa->as_min_dfa;
$DFA2 = $PFA2->as_nfa->as_min_dfa;

ok( ($DFA1->equals($DFA2)) );

__END__
# w*&w*
# throws some weird warning from FA.pm, but passes still
$PFA1 = FLAT::Regex::WithExtraOps->new('(abc)*&(def)*')->as_pfa();
$PFA2 = FLAT::Regex::WithExtraOps->new('((abc+def)*(a((bca)*bc&(def)*)+a((bca)*&(def)*)bc+d((efd)*ef&(abc)*)+d((efd)*&(abc)*)ef)*)*')->as_pfa();

$DFA1 = $PFA1->as_nfa->as_min_dfa;
$DFA2 = $PFA2->as_nfa->as_min_dfa;

ok( ($DFA1->equals($DFA2)) );
