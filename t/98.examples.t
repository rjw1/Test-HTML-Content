  use Test::HTML::Content( tests => 10 );

  $HTML = "<html><body>
           <img src='http://www.perl.com/camel.png' alt='camel'>
           <a href='http://www.perl.com'>Perl</a>
           <img src='http://www.perl.com/camel.png' alt='more camel'>
           <!--Hidden message--></body></html>";

  link_ok($HTML,"http://www.perl.com","We link to Perl");
  no_link($HTML,"http://www.pearl.com","We have no embarassing typos");
  link_ok($HTML,qr"http://[a-z]+\.perl.com","We have a link to perl.com");

  tag_ok($HTML,"img", {src => "http://www.perl.com/camel.png"},
                        "We have an image of a camel on the page");
  tag_count($HTML,"img", {src => "http://www.perl.com/camel.png"}, 2,
                        "In fact, we have exactly two camel images on the page");
  no_tag($HTML,"blink",{}, "No annoying blink tags ..." );

  # We can check the textual contents
  text_ok($HTML,"Perl");

  # We can also check the contents of comments
  comment_ok($HTML,"Hidden message");

  # Advanced stuff

  # Using a regular expression to match against
  # tag attributes - here checking there are no ugly styles
  no_tag($HTML,"p",{ style => qr'ugly$' }, "No ugly styles" );

  # REs also can be used for substrings in comments
  comment_ok($HTML,qr"[hH]idden\s+mess");
