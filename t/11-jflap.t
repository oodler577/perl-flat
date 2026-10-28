use strict;
use warnings;
use utf8;
use Test::More;
use XML::LibXML;
use FLAT;
use FLAT::PFA;
use FLAT::Regex::WithExtraOps;
use FLAT::JFLAP;
binmode Test::More->builder->output, ':encoding(UTF-8)';
binmode Test::More->builder->failure_output, ':encoding(UTF-8)';

my $fixture = <<'XML';
<?xml version="1.0" encoding="UTF-8"?>
<!-- JFLAP FA format, synthetic fixture with sparse IDs -->
<structure><type>fa</type><automaton>
 <state id="10" name="start &amp; &quot;Ω&quot;"><x>10.5</x><y>20</y><initial/><label>&lt;entry&gt;</label></state>
 <state id="42" name="middle"><x>40</x><y>50</y></state>
 <state id="99" name="done"><x>60</x><y>70</y><final/></state>
 <transition><from>10</from><to>42</to><read/></transition>
 <transition><from>42</from><to>99</to><read>a</read></transition>
 <transition><from>42</from><to>99</to><read>b</read></transition>
</automaton></structure>
XML
my $nfa = FLAT::JFLAP->from_string($fixture);
isa_ok($nfa,'FLAT::NFA');
is($nfa->num_states,3,'sparse state IDs are remapped');
is_deeply([$nfa->get_starting],[0],'initial state mapped');
is_deeply([$nfa->get_accepting],[2],'final state mapped');
ok($nfa->contains($_),"import accepts $_") for qw(a b);
ok(!$nfa->contains($_),"import rejects <$_>") for ('','aa','c');
my $xml=$nfa->as_jflap;
my $doc=XML::LibXML->load_xml(string=>$xml);
is($doc->findvalue('/structure/automaton/state[@id="0"]/@name'),'start & "Ω"','name escaped and retained');
is($doc->findvalue('/structure/automaton/state[@id="0"]/label'),'<entry>','label retained');
is($doc->findvalue('/structure/automaton/state[@id="0"]/x'),'10.5','position retained');
is($doc->findvalue('count(/structure/automaton/transition)'),3,'epsilon and parallel labels are separate XML transitions');
my $back=FLAT::JFLAP->from_string($xml);
ok($nfa->as_dfa->equals($back->as_dfa),'export/import is language equivalent');

for my $expr ('#','[]','0','a*','a+b','ab*c') {
    my $fa=FLAT::Regex->new($expr)->as_nfa;
    my $round=FLAT::JFLAP->from_string($fa->as_jflap);
    ok($fa->as_dfa->equals($round->as_dfa),"round trip $expr");
}
my $both=FLAT::NFA->singleton('a')->union(FLAT::NFA->singleton('b'));
my $both_xml=$both->as_jflap;
my $both_doc=XML::LibXML->load_xml(string=>$both_xml);
is($both_doc->findvalue('count(//initial)'),1,'multiple NFA starts normalize to one JFLAP start');
ok($both->as_dfa->equals(FLAT::JFLAP->from_string($both_xml)->as_dfa),'synthetic initial state preserves language');

for my $literal ('&','<','"',',',' ','λ','猫') {
    my $fa=FLAT::NFA->singleton($literal);
    my $round=FLAT::JFLAP->from_string($fa->as_jflap);
    ok($round->contains($literal),'literal symbol round trip');
    ok($round->as_dfa->contains($literal),'literal survives determinization');
}
my $multi=FLAT::NFA->singleton('foo');
my $error=eval { $multi->as_jflap; 1 }; ok(!$error,'multi-character token mapping is explicit');
my $expanded=FLAT::JFLAP->from_string($multi->as_jflap(expand_labels=>1));
ok($expanded->contains('foo'),'token expansion consumes its character sequence');
ok(!$expanded->contains('f'),'token expansion does not accept a prefix');
my $word_xml=$fixture; $word_xml =~ s/<read>a<\/read>/<read>xy<\/read>/;
my $word=FLAT::JFLAP->from_string($word_xml);
ok($word->contains('xy'),'JFLAP multi-character read imports as a sequence');
ok(!$word->contains('x'),'imported sequence is not a prefix');
(my $omitted=$fixture)=~s/<read\/>//;
ok(FLAT::JFLAP->from_string($omitted)->contains('a'),'omitted read is epsilon');

for my $case (
    ['',qr/empty XML/], ['<structure>',qr/malformed XML/],
    ['<structure><type>turing</type><automaton/></structure>',qr/type fa/],
    ['<!DOCTYPE structure [<!ENTITY x "a">]><structure/>',qr/DTD/],
    [$fixture =~ s/id="42"/id="10"/r,qr/duplicate/],
    [$fixture =~ s/<to>99<\/to>/<to>98<\/to>/r,qr/unknown state/],
    [$fixture =~ s/<initial\/>//r,qr/initial state/],
    [$fixture =~ s/<final\/>/<final\/><initial\/>/r,qr/initial state/],
    [$fixture =~ s/<x>40<\/x>/<x>bad<\/x>/r,qr/coordinate/],
    [$fixture =~ s/<read>a<\/read>/<read>a<\/read><read>b<\/read>/r,qr/one read/],
    [$fixture =~ s/<read>a<\/read>/<read><b\/><\/read>/r,qr/nested markup/],
    [$fixture =~ s/<automaton>/<automaton><block\/>/r,qr/unsupported element/],
) {
    eval { FLAT::JFLAP->from_string($case->[0]) };
    like($@,$case->[1],'invalid or unsupported input is rejected');
}
eval { FLAT::Regex::WithExtraOps->new('a&b')->as_pfa->as_jflap };
like($@,qr/convert a PFA/,'PFA export requires semantic NFA conversion');
eval { FLAT::NFA->singleton(qq{\x01})->as_jflap };
like($@,qr/XML 1.0/,'export rejects unrepresentable XML control characters');
my $official = FLAT::JFLAP->from_file('t/data/jflap-4-ex1.3a.jff');
ok($official->contains($_), "official JFLAP example accepts $_") for qw(aa aaa aabbb aaabbbb);
ok(!$official->contains($_), "official JFLAP example rejects <$_>") for ('', 'a', 'aab');
ok($official->as_dfa->equals(FLAT::JFLAP->from_string($official->as_jflap)->as_dfa),
   'official legacy JFLAP file round-trips through current export');
done_testing;
