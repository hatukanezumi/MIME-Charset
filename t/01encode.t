use strict;
use Test;

BEGIN { plan tests => 12 }

use MIME::Charset qw(:trans);

my ($converted, $charset, $encoding);
my $dst = "Perl:\033\$BIBE*\@^CoE*GQJ*=PNO4o\033(B";
my $src = "Perl:\xC9\xC2\xC5\xAA\xC0\xDE\xC3\xEF\xC5\xAA".
	  "\xC7\xD1\xCA\xAA\xBD\xD0\xCE\xCF\xB4\xEF";

# test get encodings for body
($converted, $charset, $encoding) = body_encode($src, "euc-jp");
if (MIME::Charset::USE_ENCODE) {
    ok($converted eq $dst);
    ok($charset eq "ISO-2022-JP");
    ok($encoding eq "7BIT");
} else {
    ok($converted eq $src);
    ok($charset eq "EUC-JP");
    ok($encoding eq "8BIT");
}

# test get encodings for body with auto-detection of 7-bit
($converted, $charset, $encoding) = body_encode($dst);
if (MIME::Charset::USE_ENCODE) {
    ok($converted eq $dst);
    ok($charset eq "ISO-2022-JP");
    ok($encoding eq "7BIT");
} else {
    ok($converted eq $dst);
    ok($charset eq "US-ASCII");
    ok($encoding eq "7BIT");
}

# test get encodings for header
($converted, $charset, $encoding) = header_encode($src, "euc-jp");
if (MIME::Charset::USE_ENCODE) {
    ok($converted eq $dst);
    ok($charset eq "ISO-2022-JP");
    ok($encoding eq "B");
} else {
    ok($converted eq $src);
    ok($charset eq "EUC-JP");
    ok($encoding eq "B");
}

# test get encodings for header with auto-detection of 7-bit
($converted, $charset, $encoding) = header_encode($dst);
if (MIME::Charset::USE_ENCODE) {
    ok($converted eq $dst);
    ok($charset eq "ISO-2022-JP");
    ok($encoding eq "B");
} else {
    ok($converted eq $dst);
    ok($charset eq "US-ASCII");
    ok(!defined $encoding);
}

