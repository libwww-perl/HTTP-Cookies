#!perl -w

require 5.008001;
use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'HTTP::Cookies',
    VERSION_FROM => 'lib/HTTP/Cookies.pm',
    ABSTRACT_FROM => 'lib/HTTP/Cookies.pm',
    AUTHOR => 'Gisle Aas <gisle@activestate.com>',
    LICENSE => "perl",
    MIN_PERL_VERSION => 5.008001,
    PREREQ_PM => {
	'HTTP::Date' => 6,
	'HTTP::Headers::Util' => 6,
	'Time::Local' => 0,
    },
    TEST_REQUIRES => {
	'URI' => 0,
    },
    META_MERGE => {
	resources => {
            repository => 'http://github.com/libwww-perl/http-cookies',
	    MailingList => 'mailto:libwww@perl.org',
        },
        provides => {
            'HTTP::Cookies' => {
                file => 'lib/HTTP/Cookies.pm',
                version => '6.01',
            },
            'HTTP::Cookies::Netscape' => {
                file => 'lib/HTTP/Cookies/Netscape.pm',
                version => '6.00',
            },
            'HTTP::Cookies::Microsoft' => {
                file => 'lib/HTTP/Cookies/Microsoft.pm',
                version => '6.00',
            },
        },
    },
);


BEGIN {
    # compatibility with older versions of MakeMaker
    my $developer = -f ".gitignore";
    my %mm_req = (
        LICENSE => 6.31,
        META_MERGE => 6.45,
        META_ADD => 6.45,
        MIN_PERL_VERSION => 6.48,
        TEST_REQUIRES => 6.64,
    );
    undef(*WriteMakefile);
    *WriteMakefile = sub {
        my %arg = @_;
        for (keys %mm_req) {
            unless (eval { ExtUtils::MakeMaker->VERSION($mm_req{$_}) }) {
                warn "$_ $@" if $developer;
                delete $arg{$_};
            }
        }
        ExtUtils::MakeMaker::WriteMakefile(%arg);
    };
}
