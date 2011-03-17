#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Email::MIME::ViewableParts' );
}

diag( "Testing Email::MIME::ViewableParts $Email::MIME::ViewableParts::VERSION, Perl $], $^X" );
