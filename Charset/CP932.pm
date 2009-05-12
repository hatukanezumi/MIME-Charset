#
# Borrowed from Encode::JP:JIS7 2.0 
#
package MIME::Charset::CP932;
use strict;
our $VERSION = '0.06';
 
use Encode qw(:fallbacks);
use Encode::EUCJPMS;

$Encode::Encoding{'x-7biteucjpms'} =
    bless { Name => 'x-7biteucjpms', sevenBits => 1 } => __PACKAGE__;
$Encode::Encoding{'x-8biteucjpms'} =
    bless { Name => 'x-8biteucjpms', sevenBits => 0 } => __PACKAGE__;

use base qw(Encode::Encoding);

# We won't support PerlIO
sub needs_lines { 0 }
sub perlio_ok { 0 }

sub decode($$;$) {
    my ($obj, $str, $chk) = @_;
    if ($obj->{sevenBits}) {
	my $residue = '';
	if ($chk) {
	    $str =~ s/([^\x00-\x7f].*)$//so and $residue = $1;
	}
	$residue .= Encode::EUCJPMS::jis_euc(\$str);
	$_[1] = $residue if $chk;
    }
    return Encode::decode('eucJP-ms', $str, $chk);
}

my $subchar = "\xA2\xAE"; # GETA MARK
sub encode($$;$) {
    my ($obj, $utf8, $chk) = @_;
    # empty the input string in the stack so perlio is ok
    $_[1] = '' if $chk;
    my @utf8 = split(/(\x1A)/, $utf8); # Workaround for UCM bug.
    my $octet = '';
    foreach my $u (@utf8) {
	unless (length $u) {
	    next;
	} elsif ($u eq '\x1A') {
	    $octet .= $u;
	} else {
	    my $o = Encode::encode('eucJP-ms', $u, $chk) ;
	    $o =~ s/\x1A/$subchar/g;
	    $octet .= $o;
	}
    }
    Encode::EUCJPMS::euc_jis(\$octet, 1) if $obj->{sevenBits};
    return $octet;
}

1;

