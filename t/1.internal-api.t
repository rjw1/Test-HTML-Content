#!/usr/bin/perl -w
use strict;
use Test::More;

# This test file tests the internal routines of Test::HTML.
# The internal routines aren't really intended for public
# consumption, but the tests you'll find in here should
# document the behaviour enough ...

# First, check the prerequisites
use_ok('Test::HTML::Content');

my (%cases_2,%cases_3);
BEGIN {
    $cases_2{__dwim_compare} = [
      "foo" => "bar" => 0,
      "foo" => "..." => 0,
      "bar" => "foo" => 0,
      "bar" => "barra" => 0,
      "barra" => "bar" => 0,

      "foo" => qr"bar" => 0,
      "foo" => qr"..." => 1,
      "bar" => qr"foo" => 0,
      "bar" => qr"barra" => 0,
      "barra" => qr"bar" => 1,

      "foo" => qr"^oo" => 0,
      "foo" => qr"oo$" => 1,
      "FOO" => qr"foo$" => 0,
      "FOO" => qr"foo$"i => 1,
    ];

    $cases_2{__match_comment} = [
      "hidden  message" => qr"hidden\s+message" => 1,
      "FOO" => qr"foo$"i => 1,
      "  FOO" => qr"foo$"i => 1,
      "FOO  " => qr"foo$"i => 0,
      "FOO  " => qr"^foo$"i => 0,
      "  hidden message  " => "hidden message" => 1,
      "  hidden message  " => "hidden  message" => 0,
    ];

    $cases_2{__match_declaration} = [
      "hidden  message" => qr"hidden\s+message" => 1,
      "FOO" => qr"foo$"i => 1,
      "  FOO" => qr"foo$"i => 1,
      "FOO  " => qr"foo$"i => 0,
      "FOO  " => qr"^foo$"i => 0,
      "  hidden message  " => "hidden message" => 1,
      "  hidden message  " => "hidden  message" => 0,
    ];

    $cases_2{__count_comments} = [
      "<html></html>" => "foo" => 0,
      "<html>foo</html>" => "foo" => 0,
      "<html><!-- foo --></html>" => "foo" => 1,
      "<html><!-- foo bar --></html>" => "foo" => 0,
      "<html><!-- bar foo --></html>" => "foo" => 0,
      "<html><!-- foo --></html>" => "foo " => 1,
      "<html><!--foo--></html>" => "foo " => 1,
      "<html><!-- bar foo --></html>" => qr"foo" => 1,
      "<html><!--foo--></html>" => "foo" => 1,
      "<html><!--foo--><!--foo--></html>" => "foo" => 2,
      "<html><!--foo--><!--foo--><!--foo--></html>" => "foo" => 3,
    ];

    $cases_3{__match} = [
      {href => 'http://www.perl.com', alt =>"foo"},{}, "href" => 0,
      {href => 'http://www.perl.com', alt =>"foo"},{}, "alt" => 0,
      {href => 'http://www.perl.com', alt =>undef},{alt => "boo"}, "alt" => 0,
      {href => undef, alt =>"foo"},{href => 'http://www.perl.com'}, "href" => 0,
      {href => 'http://www.perl.com', alt =>"foo"},{href => 'www.perl.com'}, "href" => 0,
      {href => 'http://www.perl.com', alt =>"foo"},{href => '.', alt => "foo"}, "href" => 0,

      {href => 'http://www.perl.com', alt =>"foo"},{href => 'http://www.perl.com'}, "href" => 1,
      {href => qr'www\.perl\.com'},{href => 'http://www.perl.com', alt =>"foo"}, "href" => 1,
      {href => qr'.', alt => "foo"},{href => 'http://www.perl.com', alt =>"foo"}, "href" => 1,

    ];

  my $count = 19;
  $count += @{$cases_2{$_}} / 3 for (keys %cases_2);
  $count += @{$cases_3{$_}} / 4 for (keys %cases_3);

  plan( tests => $count );
};

sub run_case {
  my ($count,$methods) = @_;
  my $method;
  for $method (sort keys %$methods) {
    while (@{$methods->{$method}}) {
      my (@params) = splice @{$methods->{$method}}, 0, $count;
      my $outcome = pop @params;
      my ($visual);
      ($visual = $method) =~ tr/_/ /;
      $visual =~ s/^\s*(.*?)\s*$/$1/;
      no strict 'refs';
      cmp_ok("Test::HTML::Content::$method"->(@params), '==',$outcome,"$visual(". join( "=~",@params ).")");
    };
  };
};

run_case( 3, \%cases_2 );
run_case( 4, \%cases_3 );

my ($count,$seen);
($count,$seen) = Test::HTML::Content::__count_tags->("<html></html>","a",{href => "http://www.perl.com"});
is($count, 0,"Counting tags 1");
is(@$seen, 0,"Checking possible candidates");
($count,$seen) = Test::HTML::Content::__count_tags->("<html><a href='http://www.python.org'>Perl</a></html>","a",{href => "http://www.perl.com"});
is($count, 0,"Counting tags 2");
is(@$seen, 1,"Checking possible candidates");
($count,$seen) = Test::HTML::Content::__count_tags->("<html><b href='http://www.python.org'>Perl</b></html>","a",{href => "http://www.perl.com"});
is($count, 0,"Counting tags 3");
is(@$seen, 0,"Checking possible candidates");
($count,$seen) = Test::HTML::Content::__count_tags->("<html><b href='http://www.perl.com'>Perl</b></html>","a",{href => "http://www.perl.com"});
is($count, 0,"Counting tags 4");
is(@$seen, 0,"Checking possible candidates");

($count,$seen) = Test::HTML::Content::__count_tags->("<html><a href='http://www.perl.com'>Perl</a></html>","a",{href => "http://www.perl.com"});
is($count, 1,"Counting tags 6");
is(@$seen, 1,"Checking possible candidates");
($count,$seen) = Test::HTML::Content::__count_tags->("<html><a href='http://www.perl.com' alt='click here'>Perl</a></html>","a",{href => "http://www.perl.com"});
is($count, 1,"Counting tags 7");
is(@$seen, 1,"Checking possible candidates");
($count,$seen) = Test::HTML::Content::__count_tags->("<html><a href='http://www.perl.com' alt=\"don't click here\">Perl</a><a href='http://www.perl.com'>Perl</a></html>","a",{href => "http://www.perl.com", alt => undef});
is($count, 1,"Counting tags 8");
is(@$seen, 2,"Checking possible candidates");
($count,$seen) = Test::HTML::Content::__count_tags->("<html><a href='http://www.perl.com' alt=\"don't click here\">Perl</a><a href='http://www.perl.com'>Perl</a></html>","a",{href => "http://www.perl.com"});
is($count, 2,"Counting tags 9");
is(@$seen, 2,"Checking possible candidates");

($count,$seen) = Test::HTML::Content::__count_tags->("<html><a href='http://www.perl.com' alt=\"don't click here\">Perl</a><foo><bar><a href='http://www.perl.com'>Perl</a></bar></html>","a",{href => "http://www.perl.com"});
is($count, 2,"Counting tags 9");
is(@$seen, 2,"Checking possible candidates");