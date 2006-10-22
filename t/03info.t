use strict;
use Test::More qw(no_plan);
use MIME::Charset qw(:info);

ok(body_encoding("iso-8859-2") eq "Q");
ok(canonical_charset("ANSI X3.4-1968") eq "US-ASCII");
ok(header_encoding("utf-8") eq "S");
ok(output_charset("shift_jis") eq "ISO-2022-JP");

