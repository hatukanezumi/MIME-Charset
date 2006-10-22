use strict;
use Test;

BEGIN { plan tests => 4 }

use MIME::Charset qw(:info);

ok(body_encoding("iso-8859-2") eq "Q");
if (MIME::Charset::USE_ENCODE) {
    ok(canonical_charset("ANSI X3.4-1968") eq "US-ASCII");
} else {
    ok(canonical_charset("ascii") eq "US-ASCII");
}
ok(header_encoding("utf-8") eq "S");
if (MIME::Charset::USE_ENCODE) {
    ok(output_charset("shift_jis") eq "ISO-2022-JP");
} else {
    ok(output_charset("shift_jis") eq "SHIFT_JIS");
}
