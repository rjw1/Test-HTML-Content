package Test::HTML::Content;

require 5.005_62;
use strict;

# we want to stay compatible to 5.5 and use warnings if
# we can
eval 'use warnings' if $] >= 5.006;
use Test::Builder;
require Exporter;

use vars qw/@ISA @EXPORT_OK @EXPORT $VERSION/;

use HTML::TokeParser;

@ISA = qw(Exporter);

# TODO:
# * Implement a cache for the last parsed tree / token sequence
# * Possibly diag() the row/line number for failing tests
# * Create a function (and a syntax) to inspect tag text contents
#   (possibly a special attribute) ? Will not happen until HTML::TreeBuilder is used
# * Consider HTML::TableExtractor for easy parsing of
#   tables into arrays
# * Find syntax for easily specifying relationships
# * Consider HTML::TreeBuilder for more advanced structural checks
# * Have a way of declaring "the link that shows 'foo' points to http://www.foo.com/"
#   (which is, after all, a way to check a tags contents, and thus won't happen
#   until HTML::TreeBuilder is used)
# ? Allow RE instead of plain strings in the functions (for tags themselves)

# DONE:
# * use Test::Builder;
# * Add comment_ok() method
# * Allow RE instead of plain strings in the functions (for tag attributes and comments)
# * Create a function to check the DOCTYPE and other directives
# * Have a better way to diagnose ignored candidates in tag_ok(), tag_count
#   and no_tag() in case a test fails

#our %EXPORT_TAGS = ( 'all' => [] );
#our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

@EXPORT = qw(
  link_ok no_link link_count
  tag_ok no_tag tag_count
  comment_ok no_comment comment_count
  has_declaration no_declaration
  );

$VERSION = '0.02';

my $Test = Test::Builder->new;
use vars qw($HTML_PARSER_StripsTags);

BEGIN {
  # Check whether HTML::Parser is v3 and delivers the comments starting
  # with the <!--, even though that's implied :
  my $HTML = "<!--Comment-->";
  my $p = HTML::TokeParser->new(\$HTML);
  my ($type,$text) = @{$p->get_token()};
  if ($text eq "<!--Comment-->") {
    $HTML_PARSER_StripsTags = 0
  } else {
    $HTML_PARSER_StripsTags = 1
  };
};

# Cribbed from the Test::Builder synopsis
sub import {
    my($self) = shift;
    my $pack = caller;
    $Test->exported_to($pack);
    $Test->plan(@_);
    $self->export_to_level(1, $self, @EXPORT);
}

sub __dwim_compare {
  # Do the Right Thing (Perl 6 style) with the RHS being a Regex or a string
  my ($target,$template) = @_;
  if (ref $template) { # supposedly a Regexp, but possibly blessed, so no eq comparision
    return ($target =~ $template )
  } else {
    return $target eq $template;
  };
};

sub __match_comment {
  my ($text,$template) = @_;
  $text =~ s/^<!--(.*?)-->$/$1/ unless $HTML_PARSER_StripsTags;
  unless (ref $template eq "Regexp") {
    $text =~ s/^\s*(.*?)\s*$/$1/;
    $template =~ s/^\s*(.*?)\s*$/$1/;
  };
  return __dwim_compare($text, $template);
};

sub __count_comments {
  my ($HTML,$comment) = @_;
  my $result = 0;

  my $p = HTML::TokeParser->new(\$HTML);
  my $token;
  while ($token = $p->get_token) {
    my ($type,$text) = @$token;
    if ($type eq "C" && __match_comment($text,$comment)) {
      $result ++;
    };
  };

  return $result;
};

sub comment_ok {
  my ($HTML,$comment,$name) = @_;
  my $result = __count_comments($HTML,$comment);

  $Test->cmp_ok($result,'>',0,$name);
};

sub no_comment {
  my ($HTML,$comment,$name) = @_;
  $comment =~ s/^\s*(.*?)\s*$/$1/;
  my $result = __count_comments($HTML,$comment);

  $Test->is_num($result,0,$name);
};

sub comment_count {
  my ($HTML,$comment,$count,$name) = @_;
  my $result = __count_comments($HTML,$comment);
  $Test->is_num($result,$count,$name);
};

sub __match {
  my ($attrs,$currattr,$key) = @_;
  my $result = 1;

  if (exists $currattr->{$key}) {
    if (! defined $attrs->{$key}) {
      $result = 0; # We don't want to see this attribute here
    } else {
      $result = 0 unless __dwim_compare($currattr->{$key}, $attrs->{$key});
    };
  } else {
    if (! defined $attrs->{$key}) {
      $result = 0 if (exists $currattr->{$key});
    } else {
      $result = 0;
    };
  };
  return $result;
};

sub __count_tags {
  my ($HTML,$tag,$attrref) = @_;
  $attrref = {} unless defined $attrref;

  my $result = 0;

  my $p = HTML::TokeParser->new(\$HTML);
  my $token;
  my $seen = [];
  while ($token = $p->get_token) {
    my ($type,$currtag,$currattr,$attrseq,$origtext) = @$token;
    if ($type eq "S" && $tag eq $currtag) {
      my (@keys) = keys %$attrref;
      my $key;
      my $complete = 1;
      foreach $key (@keys) {
        $complete = __match($attrref,$currattr,$key) if $complete;
      };
      $result += $complete;
      push @$seen, [@$token];
    };
  };

  return $result,$seen;
};

sub __tag_diag {
  my ($tag,$num,$attrs,$found) = @_;
  my $phrase = "Expected to find $num <$tag> tag(s)";
  $phrase .= " matching" if (scalar keys %$attrs > 0);
  $Test->diag($phrase);
  $Test->diag("  $_ = " . $attrs->{$_}) for sort keys %$attrs;
  if (@$found) {
    $Test->diag("Got");
    $Test->diag("  " . $_->[4]) for @$found;
  } else {
    $Test->diag("Got none");
  };
};

sub tag_count {
  my ($HTML,$tag,$attrref,$count,$name) = @_;
  my ($currcount,$seen) = __count_tags($HTML,$tag,$attrref);
  my $result = $count == $currcount;
  unless ($Test->ok($result, $name)) {
    __tag_diag($tag,"exactly $count",$attrref,$seen) ;
  };
  $result;
};

sub tag_ok {
  my ($HTML,$tag,$attrref,$name) = @_;
  unless (defined $name) {
     if (! ref $attrref) {
       $Test->diag("Usage ambiguity: tag_ok() called without specified tag attributes");
       $Test->diag("(I'm defaulting to any attributes)");
       $name = $attrref;
       $attrref = {};
     };
  };
  my ($count,$seen) = __count_tags($HTML,$tag,$attrref);
  my $result = $Test->ok( $count > 0, $name );
  __tag_diag($tag,"at least one",$attrref,$seen) unless ($result);
  $result;
};

sub no_tag {
  my ($HTML,$tag,$attrref,$name) = @_;
  my ($count,$seen) = __count_tags($HTML,$tag,$attrref);
  my $result = $count == 0;
  $Test->ok($result,$name);
  __tag_diag($tag,"no",$attrref,$seen) unless ($result);
  $result;
};

sub link_count {
  my ($HTML,$link,$count,$name) = @_;
  #my ($HTML,$tag,$attrref,$count,$name) = @_;
  return tag_count($HTML,"a",{href => $link},$count,$name);
};

sub link_ok {
  my ($HTML,$link,$name) = (@_);
  return tag_ok($HTML,'a',{ href => $link },$name);
};

sub no_link {
  my ($HTML,$link,$name) = (@_);
  return no_tag($HTML,'a',{ href => $link },$name);
};

sub __match_declaration {
  my ($text,$template) = @_;
  $text =~ s/^<!(.*?)>$/$1/ unless $HTML_PARSER_StripsTags;
  unless (ref $template eq "Regexp") {
    $text =~ s/^\s*(.*?)\s*$/$1/;
    $template =~ s/^\s*(.*?)\s*$/$1/;
  };
  return __dwim_compare($text, $template);
};

sub __count_declarations {
  my ($HTML,$doctype) = @_;
  my $result = 0;
  my $seen = [];

  my $p = HTML::TokeParser->new(\$HTML);
  my $token;
  while ($token = $p->get_token) {
    my ($type,$text) = @$token;
    if ($type eq "D") {
      push @$seen, $text;
      $result++ if __match_declaration($text,$doctype);
    };
  };

  return $result, $seen;
};

sub has_declaration {
  my ($HTML,$declaration,$name) = @_;
  my ($result,$seen) = __count_declarations($HTML,$declaration);

  unless ($Test->ok($result == 1,$name)) {
    # Output what we saw to faciliate debugging
    if (@$seen) {
      $Test->diag( "Saw '$_'" ) for @$seen;
    } else {
      $Test->diag( "No declaration found" );
    };
    $Test->diag( "Expected something like '$declaration'" );
  };
};

sub no_declaration {
  my ($HTML,$declaration,$name) = @_;
  my ($result,$seen) = __count_declarations($HTML,$declaration);

  unless ($Test->ok($result == 0,$name)) {
    # Output what we saw to faciliate debugging
    if (@$seen) {
      $Test->diag( "Saw '$_'" ) for @$seen;
    } else {
      $Test->diag( "No declaration found" );
    };
    $Test->diag( "Expected to find nothing like '$declaration'" );
  };
};

1;

__END__

=head1 NAME

Test::HTML::Content - Perl extension for testing HTML output

=head1 SYNOPSIS

  use Test::HTML::Content;

  $HTML = "<html><body>
           <a href='http://www.perl.com'>Perl</a>
           <!--Hidden message--></body></html>";

  link_ok($HTML,"http://www.perl.com","We link to Perl");
  no_link($HTML,"http://www.pearl.com","We have no embarassing typos");
  no_link($HTML,qr"http://[a-z]+\.perl.com","We have a link to perl.com");

  tag_ok($HTML,"img", {src => "http://www.perl.com/camel.png"},
                        "We have an image of a camel on the page");
  tag_count($HTML,"img", {src => "http://www.perl.com/camel.png"}, 2,
                        "In fact, we have exactly two camel images on the page");
  no_tag($HTML,"blink",{}, "No annoying blink tags ..." );

  # We can also check the contents of comments
  comment_ok($HTML,"Hidden message");

  # Advanced stuff

  # Using a regular expression to match against
  # tag attributes - here checking there are no ugly styles
  no_tag($HTML,"p",{ style => qr'ugly$' }, "No ugly styles" );

  # REs also can be used for substrings in comments
  comment_ok($HTML,qr"[hH]idden\s+mess");

=head1 DESCRIPTION

This is a module to test the HTML output of your programs in simple
test scripts. It can test a scalar (presumably containing HTML) for
the presence (or absence, or a specific number) of tags having (or
lacking) specific attributes. Unspecified attributes are ignored,
and the attribute values can be specified as either scalars (meaning
a match succeeds if the strings are identical) or regular expressions
(meaning that a match succeeds if the actual attribute value is matched
by the given RE) or undef (meaning that the attribute must not
be present).

There is no way (yet) to specify or test the deeper structure
of the HTML (for example, META tags within the BODY) or the (textual)
content of tags. The next generation will most likely be based on
HTML::TreeBuilder to alleviate that situation, or implement
its own scheme.

The used HTML parser is HTML::TokeParser.

The test functionality is derived from L<Test::Builder>, and the export
behaviour is the same. When you use Test::HTML::Content, a set of
HTML testing functions is exported into the namespace of the caller.

=head2 EXPORT

Exports the bunch of test functions :

  link_ok() no_link() link_count()
  tag_ok() no_tag() tag_count()
  comment_ok() no_comment() comment_count()
  has_declaration() no_declaration()

=head2 CONSIDERATIONS

The module reparses the HTML string every time a test function is called.
This will make running many tests over the same, large HTML stream relatively
slow. I plan to add a simple minded caching mechanism that keeps the most
recent HTML stream in a cache.

=head2 TODO

My things on the todo list for this module. Patches are welcome !

=over4

=item * Implement a cache for the last parsed tree / token sequence

=item * Possibly diag() the row/line number for failing tests

=item * Create a function (and a syntax) to inspect tag text contents without
reimplementing XSLT. ?possibly a special attribute? Will not happen 
until HTML::TreeBuilder is used

=item * Consider HTML::TableExtractor for easy parsing of tables into arrays
and then subsequent testing of the arrays

=item * Find syntax for easily specifying relationships between tags
(see XSLT comment above)

=item * Consider HTML::TreeBuilder for more advanced structural checks

=item * Have a way of declaring "the link that shows 'foo' points to http://www.foo.com/"
(which is, after all, a way to check a tags contents, and thus won't happen
until HTML::TreeBuilder is used)

=item * Allow RE instead of plain strings in the functions (for tags themselves). This
one is most likely useless.

=back

=head1 LICENSE

This code may be distributed under the same terms as Perl itself.

=head1 AUTHOR

Max Maischein, corion@cpan.org

=head1 SEE ALSO

perl(1), L<Test::Builder>,L<Test::Simple>,L<HTML::TokeParser>,L<Test::HTML::Lint>.

=cut