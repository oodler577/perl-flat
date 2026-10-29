package FLAT::Regex::Lexer;
use strict;
use warnings;
use Carp qw(croak);
use FLAT::Regex::ParseError;
sub new {
    my ($class,%options)=@_;
    my $self=bless {max_length=>1_000_000,max_token_length=>65_536,%options},$class;
    croak "unknown lexer option '$_'" for grep { !/\A(?:max_length|max_token_length)\z/ } keys %options;
    for (values %$self) { croak 'lexer limits must be positive integers' unless defined && !ref && /\A[1-9][0-9]*\z/ }
    return $self;
}
sub tokenize {
    my ($self,$text)=@_;
    die FLAT::Regex::ParseError->new(message=>'expected a defined character string',offset=>0,line=>1,column=>1)
        if !defined($text) || ref($text);
    die FLAT::Regex::ParseError->new(message=>'expression exceeds max_length',offset=>0,line=>1,column=>1)
        if length($text)>$self->{max_length};
    my (@tokens,$line,$column);
    ($line,$column)=(1,1);
    pos($text)=0;
    while (pos($text)<length($text)) {
        my $start=pos($text);
        my ($sl,$sc)=($line,$column);
        my ($type,$value,$chunk);
        if ($text =~ /\G\s+/gc) { $chunk=$& }
        elsif ($text =~ /\G\[([^\]]*)\]/gc) {
            ($type,$value,$chunk)=('atom',$1,$&);
            die FLAT::Regex::ParseError->new(message=>'symbol exceeds max_token_length',offset=>$start,line=>$sl,column=>$sc)
                if length($value)>$self->{max_token_length};
        }
        elsif ($text =~ /\G([A-Za-z0-9_\$\#\%\@;:\-\^])/gc) {
            ($type,$value,$chunk)=('atom',$1,$1);
            $value=undef if $value eq '#';
        }
        elsif ($text =~ /\G([()+|&*~])/gc) { ($type,$value,$chunk)=($1,$1,$1) }
        else {
            my $char=substr($text,$start,1);
            my $message=$char eq '[' ? 'unterminated bracketed symbol' : sprintf('unexpected character U+%04X; quote literal symbols in brackets',ord($char));
            die FLAT::Regex::ParseError->new(message=>$message,offset=>$start,line=>$sl,column=>$sc);
        }
        my $newlines=($chunk =~ tr/\n/\n/);
        if ($newlines) { $line+=$newlines; $column=length($chunk)-rindex($chunk,"\n") }
        else { $column+=length($chunk) }
        push @tokens,{type=>$type,value=>$value,start=>$start,end=>pos($text),line=>$sl,column=>$sc,end_line=>$line,end_column=>$column}
            if defined $type;
    }
    push @tokens,{type=>'eof',start=>length($text),end=>length($text),line=>$line,column=>$column,end_line=>$line,end_column=>$column};
    return \@tokens;
}
1;
__END__

=head1 NAME

FLAT::Regex::Lexer - literal tokens and source locations for formal REs

=head1 CONTRACT

C<tokenize($text)> returns token hashes with C<type>, C<value>, C<start>,
C<end>, C<line>, C<column>, C<end_line>, and C<end_column>. End offsets are
exclusive. A final C<eof> token is included. Whitespace is skipped outside
brackets. C<#> is empty language, C<[]> is epsilon, and C<[#]> is a literal key.
Bracket contents are literal, including whitespace and backslashes; there is
no backslash escape convention or Perl pattern syntax. Non-ASCII keys must be
bracketed. Unicode normalization is not performed. Input is a Perl character
string; byte decoding belongs to the caller or CLI input layer.

C<new> accepts positive integer C<max_length> (default 1,000,000 characters)
and C<max_token_length> (65,536). Invalid input throws L<FLAT::Regex::ParseError>.

=cut
