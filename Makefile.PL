use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'    => 'Test::HTML::Content',
    'VERSION_FROM'  => 'Content.pm', # finds $VERSION
    'PREREQ_PM'    => {Test::Builder => 0.0,
              Test::More => 0.0,
              HTML::TokeParser => 0.0}, # e.g., Module::Name => 1.1
);