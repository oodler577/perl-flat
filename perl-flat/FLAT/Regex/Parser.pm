package FLAT::Regex::Parser;
use strict;

#### Is this one level of abstraction too far? Parser generator generators..

#### TODO: try YAPP, since recursive descent is SLOOOW
use Parse::RecDescent;
use FLAT::Regex::Op;

use vars '$CHAR';
$CHAR = qr{ [A-Za-z0-9_\$\#] | \[[^\]]*\] }x;

sub new {
    my $pkg = shift;
    my @ops = sort { "FLAT::Regex::Op::$a"->precedence
                        <=> "FLAT::Regex::Op::$b"->precedence }
              @_;

    my $prev      = shift @ops;
    my $lowest    = $prev;

    my $grammar = qq!
            parse:
                $prev /^\\Z/ { \$item[1] }
    !;
    
    for (@ops) {
        my $spec = sprintf "FLAT::Regex::Op::$prev"->parse_spec, $_;
        
        $grammar .= qq!
            $prev:
                $spec { FLAT::Regex::Op::$prev->from_parse(\@item) }
              | $_ { \$item[1] }
        !;
        
        $prev = $_;
    }            

    my $spec = sprintf "FLAT::Regex::Op::$prev"->parse_spec, "atomic";
    $grammar .= qq!
            $prev:
                $spec { FLAT::Regex::Op::$prev->from_parse(\@item) }
              | atomic { \$item[1] }

            atomic:
                "(" $lowest ")" { \$item[2] }
              | /\$FLAT::Regex::Parser::CHAR/
                          { FLAT::Regex::Op::atomic->from_parse(\@item) }
    !;

    Parse::RecDescent->new($grammar);
}

1;


__END__

use vars '$CHAR';
$CHAR = qr{ [A-Za-z0-9_\!\@\#\$\%\&] | \[[^\]]*\] }x;

my $PARSER = Parse::RecDescent->new(<<'__EOG__') or die;
  parse:
      alt /^\Z/            { $item[1] }
  alt:
      concat(2.. /[+|]/)   { FLAT::Regex::Op::alt->from_parse(@item) }
    | concat               { $item[1] }
  concat:
      star(2..)            { FLAT::Regex::Op::concat->from_parse(@item) }
    | star                 { $item[1] }
  star :
      atomic '*'           { FLAT::Regex::Op::star->from_parse(@item) }
    | atomic               { $item[1] }
  atomic:
      "(" alt ")"          { $item[2] }
    | /$FLAT::Regex::CHAR/ { FLAT::Regex::Op::atomic->from_parse(@item) }
__EOG__
