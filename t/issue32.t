use strict;
use warnings;
use Test::More;

use HTTP::Cookies  ();
use HTTP::Request  ();
use HTTP::Response ();

# GH issue #32 (rt.cpan.org #70721) was reported against *version-1* cookies,
# whose quoting is defined by RFC 2965 and handled on the Set-Cookie2 path
# (_split_header_words). PR #49 mistakenly taught the v0 (Netscape) Set-Cookie
# path to process quotes and backslashes too, which broke RFC 6265 compliance
# (see GH #73). That quote handling has been reverted: the v0 path now splits
# only on ";" and keeps the value verbatim, per RFC 6265 5.2.
#
# This test pins the RFC 6265 parse of the header from #32's own repro: with no
# quoting on the v0 path, a="b;c;\"d" is split on ";", so cookie "a" takes the
# value '"b' rather than folding the ";"-separated remainder back into it.

my $nextyear = 1901 + ( gmtime() )[5];

my $req  = HTTP::Request->new( GET => "http://example.com" );
my $resp = HTTP::Response->new(
    200, 'OK',
    [
        'Set-Cookie',
        q!a="b;c;\\"d"; expires=Fri, 06-Nov-!
            . $nextyear
            . " 08:58:34 GMT; domain=example.com; path=/"
    ]
);
$resp->request($req);

my $c = HTTP::Cookies->new;
$c->extract_cookies($resp);

my $value;
$c->scan( sub { $value = $_[2] if $_[1] eq 'a' } );
is $value, '"b', 'RFC 6265: a="b;c;\"d" splits on ";" so value is "b';

done_testing;
