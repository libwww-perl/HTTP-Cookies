use strict;
use warnings;
use Test::More;

use HTTP::Cookies  ();
use HTTP::Request  ();
use HTTP::Response ();

# GH issue #69: the Max-Age attribute on a Set-Cookie header was parsed but
# never carried through to the stored cookie, so Max-Age was completely
# ignored -- cookies got no expiry and Max-Age=0 failed to delete them.

sub jar_with_set_cookie {
    my $set_cookie = shift;
    my $req  = HTTP::Request->new( GET => 'http://example.com/' );
    my $resp = HTTP::Response->new( 200, 'OK', [ 'Set-Cookie', $set_cookie ] );
    $resp->request($req);
    my $jar = HTTP::Cookies->new;
    $jar->extract_cookies($resp);
    return $jar;
}

subtest 'Max-Age sets a future expiry' => sub {
    my $jar = jar_with_set_cookie(
        'foo=bar; domain=example.com; path=/; Max-Age=3600');

    my $expires;
    $jar->scan( sub { $expires = $_[8] } );

    ok defined $expires, 'cookie has an expiry derived from Max-Age';
    cmp_ok $expires, '>', time(), 'expiry is in the future'
        if defined $expires;
};

subtest 'Max-Age=0 deletes the cookie' => sub {
    my $jar = jar_with_set_cookie(
        'foo=bar; domain=example.com; path=/; Max-Age=0');

    my $count = 0;
    $jar->scan( sub { $count++ } );

    is $count, 0, 'cookie with Max-Age=0 is not stored';
};

subtest 'non-numeric Max-Age is ignored (RFC 6265 5.2.2)' => sub {
    # A malformed Max-Age must be ignored, not treated as 0. Treating it as 0
    # would coerce the string to 0 in set_cookie and wrongly delete the cookie.
    my $jar = jar_with_set_cookie(
        'foo=bar; domain=example.com; path=/; Max-Age=not-a-number');

    my $count = 0;
    $jar->scan( sub { $count++ } );

    is $count, 1, 'cookie with a non-numeric Max-Age is still stored';
};

subtest 'an absurdly large Max-Age is capped at ~10 years' => sub {
    # Without a cap, a huge value makes time() + $maxage a float, which
    # serializes to garbage and silently downgrades to a session cookie.
    # Mirror the expires branch, which caps far-future dates at 10 years.
    my $ten_years = 10 * 365 * 24 * 60 * 60;
    my $jar = jar_with_set_cookie(
        'foo=bar; domain=example.com; path=/; Max-Age=' . ( '9' x 30 ) );

    my $expires;
    $jar->scan( sub { $expires = $_[8] } );

    ok defined $expires, 'cookie is stored with an expiry';
    cmp_ok $expires, '>', time(), 'expiry is in the future'
        if defined $expires;
    cmp_ok $expires, '<=', time() + $ten_years + 10,
        'huge Max-Age is capped at ~10 years, not a float overflow'
        if defined $expires;
};

done_testing;
