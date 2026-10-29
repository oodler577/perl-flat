use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use FLAT::Regex::WithExtraOps;
BEGIN { eval { require Parse::RecDescent; 1 } or plan skip_all=>'optional Parse::RecDescent oracle dependency missing' }
use FLAT::Regex::RecDescentOracle;
my @invalid=('',')ab','a(bc(d)','ab)cd(ef','a+b+','a++b','+a','h**','a+*','()', 'a~b','~~a','a&','[foo','a?');
srand 577;
sub expression {
    my ($depth,$extended)=@_;
    return ('a','b','[]','#','[foo]','[ ]','[#]')[rand 7] if !$depth || rand()<0.4;
    my $a=expression($depth-1,$extended);
    my $b=expression($depth-1,$extended);
    my $kind=int rand($extended ? 5 : 3);
    return "($a)*" if $kind==0;
    return "($a)($b)" if $kind==1;
    return "($a)+($b)" if $kind==2;
    return "($a)&($b)" if $kind==3;
    return "~($a)";
}
for my $extra (0,1) {
    my @ops=(qw(alt concat star),$extra ? qw(negate shuffle) : ());
    my $native=FLAT::Regex::Parser->new(@ops);
    my $legacy=FLAT::Regex::RecDescentOracle->new(@ops);
    my @corpus=(@invalid,'a|b','[]','#','a b','[\\]','[[x]','[a\nb]','a(~b)','~ab&c');
    for (1..60) {
        my $s=expression(2,$extra);
        push @corpus,$s;
    }
    for my $s (@corpus) {
        my $new=$native->parse($s);
        my $old=$legacy->parse($s);
        is(defined($new),defined($old),"grammar acceptance parity ($extra)");
        is_deeply($new,$old,"AST parity ($extra)") if defined($new) && defined($old);
    }
}
done_testing;
