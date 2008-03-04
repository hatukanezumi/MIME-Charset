use strict;
use Test;

BEGIN { plan tests => 4 }

use MIME::Charset qw(:info);

my $obj;
$obj = MIME::Charset->new("iso-8859-2");
ok($obj->body_encoding eq "Q");
if (MIME::Charset::USE_ENCODE) {
    $obj = MIME::Charset->new("ANSI X3.4-1968");
    ok($obj->canonical_charset eq "US-ASCII");
} else {
    $obj = MIME::Charset->new("ascii");
    ok($obj->canonical_charset eq "US-ASCII");
}
$obj = MIME::Charset->new("utf-9");
ok($obj->header_encoding eq "S");
$obj = MIME::Charset->new("shift_jis");
if (MIME::Charset::USE_ENCODE) {
    ok($obj->output_charset eq "ISO-2022-JP");
} else {
    ok($obj->output_charset eq "SHIFT_JIS");
}
