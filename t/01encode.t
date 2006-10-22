use strict;
use Test;

BEGIN { plan tests => 6 }

use MIME::Charset qw(:trans);

my ($converted, $charset, $encoding);
my $dst = "\033\$BIBE*\@^CoE*GQJ*=PNO4o\033(B";
my $src = "\xC9\xC2\xC5\xAA\xC0\xDE\xC3\xEF\xC5\xAA".
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

