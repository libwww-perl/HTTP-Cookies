use strict;
use warnings;
use Test::More 0.96;    # subtest

use HTTP::Cookies  ();
use HTTP::Request  ();
use HTTP::Response ();

# GH issue #73: the v0 (Netscape / RFC 6265) Set-Cookie path must not apply
# quote or backslash processing. RFC 6265 5.2 parses a Set-Cookie header by
# splitting on ";" and on the first "=" only, keeping the value verbatim --
# double quotes and backslashes are ordinary characters, not delimiters.
#
# PR #49 wired a quote-aware splitter (_split_text) into this path to satisfy
# issue #32, but #32 was about version-1 (RFC 2965) cookies, which arrive in
# the Set-Cookie2 header and are parsed separately by _split_header_words.
# Applying quote handling to the v0 path broke the common, spec-legal case
# below (foo="bar" round-tripping to foo=bar).

sub roundtrip {
    my $set_cookie = shift;
    my $req        = HTTP::Request->new( GET => 'http://example.com/' );
    my $resp
        = HTTP::Response->new( 200, 'OK', [ 'Set-Cookie', $set_cookie ] );
    $resp->request($req);
    my $jar = HTTP::Cookies->new;
    $jar->extract_cookies($resp);

    my $out = HTTP::Request->new( GET => 'http://example.com/' );
    $jar->add_cookie_header($out);
    return $out->header('Cookie');
}

subtest 'a double-quoted value keeps its quotes verbatim' => sub {

    # RFC 6265 5.2: quotes are part of the value, not stripped.
    is roundtrip('foo="bar"; path=/'), 'foo="bar"',
        'foo="bar" is sent back unchanged, not as foo=bar';
};

subtest 'a backslash in the value is preserved verbatim' => sub {

    # The v0 path must not treat "\\" as an escape character.
    is roundtrip('sess=a\\b; path=/'), 'sess=a\\b',
        'a literal backslash survives extraction';
};

subtest 'the value is split on ";" per RFC 6265' => sub {

    # A ";" inside a would-be "quoted" value still terminates the value,
    # because v0 has no quoting: a="b;c" yields the cookie value '"b'.
    my $req  = HTTP::Request->new( GET => 'http://example.com/' );
    my $resp = HTTP::Response->new(
        200, 'OK',
        [ 'Set-Cookie', 'a="b;c"; domain=example.com; path=/' ]
    );
    $resp->request($req);
    my $jar = HTTP::Cookies->new;
    $jar->extract_cookies($resp);

    my $value;
    $jar->scan( sub { $value = $_[2] if $_[1] eq 'a' } );
    is $value, '"b', 'a="b;c" parses to value "b (split on the ";")';
};

done_testing;
