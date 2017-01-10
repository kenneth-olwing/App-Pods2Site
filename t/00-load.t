use strict;
use warnings;

use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'App::Pods2Site' ) || print "Bail out!\n";
}

diag( "Testing App::Pods2Site $App::Pods2Site::VERSION, Perl $], $^X" );
