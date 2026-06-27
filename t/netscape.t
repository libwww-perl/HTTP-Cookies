#!perl -w

# Session cookies (no expiry) must round-trip through the Netscape/cookies.txt
# format the same way curl and yt-dlp treat them: written with an expiry of 0,
# and read back as a session cookie (not as an ancient/expired cookie).

use strict;
use warnings;

use Test::More tests => 6;

use File::Temp qw(tempdir);
use File::Spec ();

use HTTP::Cookies::Netscape;

my $dir  = tempdir( CLEANUP => 1 );
my $file = File::Spec->catfile( $dir, 'cookies.txt' );

sub cookie_names {
    my $jar = shift;
    my %names;
    $jar->scan( sub { $names{ $_[1] } = 1 } );
    return \%names;
}

# A session cookie has no Max-Age/Expires, so set_cookie() gets an undef maxage.
my $jar = HTTP::Cookies::Netscape->new;
$jar->set_cookie(
    undef, 'sessionid', 'abc123', '/', '.example.com', undef,
    0,     0,           undef,    0
);

# A normal persistent cookie, far in the future.
$jar->set_cookie(
    undef, 'persistent', 'xyz789',             '/', '.example.com', undef,
    0,     0,            10 * 365 * 24 * 3600, 0
);

is_deeply(
    cookie_names($jar), { sessionid => 1, persistent => 1 },
    'jar holds both cookies before saving'
);

$jar->save($file);

my $content = do {
    open my $fh, '<', $file or die "open $file: $!";
    local $/;
    <$fh>;
};

like(
    $content,
    qr/^\.example\.com\t.*\t0\tsessionid\tabc123$/m,
    'session cookie is written with an expiry of 0 (curl convention)'
);
like(
    $content,
    qr/\tpersistent\txyz789$/m,
    'persistent cookie is written'
);

my $loaded = HTTP::Cookies::Netscape->new( file => $file );

ok(
    cookie_names($loaded)->{sessionid},
    'session cookie survives a save/load round-trip'
);
ok(
    cookie_names($loaded)->{persistent},
    'persistent cookie survives a save/load round-trip'
);

# Regression guard: a cookie whose expiry is already in the past must NOT be
# saved. (maxage of 1s, then we doctor the stored expiry into the past.)
my $expired = HTTP::Cookies::Netscape->new;
$expired->set_cookie(
    undef, 'stale', 'old', '/', '.example.com', undef,
    0,     0,       1,     0
);
$expired->scan( sub { } );    # no-op, keeps API parallel

# Force the stored absolute expiry into the past.
$expired->{COOKIES}{'.example.com'}{'/'}{stale}[5] = time - 3600;
my $expfile = File::Spec->catfile( $dir, 'expired.txt' );
$expired->save($expfile);
my $expired_loaded = HTTP::Cookies::Netscape->new( file => $expfile );
ok(
    !cookie_names($expired_loaded)->{stale},
    'already-expired cookie is not saved'
);
