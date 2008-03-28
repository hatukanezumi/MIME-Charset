use strict;
use Test;

BEGIN { plan tests => 25 }

my @names = qw(
	    US-ASCII
	    ISO-8859-1 ISO-8859-2 ISO-8859-3 ISO-8859-4 ISO-8859-5
	    ISO-8859-6 ISO-8859-7 ISO-8859-8 ISO-8859-9 ISO-8859-10
	    SHIFT_JIS EUC-JP ISO-2022-KR EUC-KR ISO-2022-JP ISO-2022-JP-2
	    ISO-8859-6-I ISO-8859-6-E ISO-8859-8-E ISO-8859-8-I
	    GB2312 BIG5 KOI8-R
	    UTF-8
	   );

use MIME::Charset qw(:info);

foreach my $name (@names) {
    my $aliased = MIME::Charset->new($name)->as_string;
    ok($aliased, $name, $aliased);
}
