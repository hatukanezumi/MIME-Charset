use strict;
use Test::More qw(no_plan);
use Encode;
use MIME::Charset qw(:trans);

my ($converted, $charset, $encoding);
my $dst = "\033\$BIBE*\@^CoE*GQJ*=PNO4o\033(B";
my $src = $dst;
Encode::from_to($src, "iso-2022-jp", "euc-jp");

# test get encodings for body
($converted, $charset, $encoding) = body_encode($src, "euc-jp");
ok($converted eq $dst);
ok($charset eq "ISO-2022-JP");
ok($encoding eq "7BIT");

# test get encodings for header
($converted, $charset, $encoding) = header_encode($src, "euc-jp");
ok($converted eq $dst);
ok($charset eq "ISO-2022-JP");
ok($encoding eq "B");

