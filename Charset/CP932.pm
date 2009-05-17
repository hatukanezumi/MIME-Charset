=encoding utf-8

Borrowed from Encode::JP:JIS7 2.0.

=cut

package MIME::Charset::CP932;
use strict;
our $VERSION = '0.07';
 
use Encode qw(:fallbacks);
use Encode::EUCJPMS;

$Encode::Encoding{'x-7biteucjpascii'} =
    bless { Name => 'x-7biteucjpascii',
	    sevenBits => 1,
	    shiftEncoding => 0 } => __PACKAGE__;
$Encode::Encoding{'x-8biteucjpascii'} =
    bless { Name => 'x-8biteucjpascii',
	    sevenBits => 0,
	    shiftEncoding => 0 } => __PACKAGE__;
$Encode::Encoding{'x-shifteucjpascii'} =
    bless { Name => 'x-shifteucjpascii',
	    sevenBits => 0,
	    shiftEncoding => 1 } => __PACKAGE__;

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
	my @s = split /(\e\(J[\x21-\x7E]*)/, $str;
	foreach my $s (@s) {
	    unless (length $s) {
		next;
	    } elsif ($s =~ /^\e\(J([\x21-\x7E]*)/) {
		next unless length $1;
		$residue .= $s;
	    } else {
		$residue .= Encode::EUCJPMS::jis_euc(\$s);
	    }
	}
	$_[1] = $residue if $chk;
    }
    my @str;
    if ($obj->{shiftEncoding}) {
	@str = ($str);
    } else {
	@str = split /(\x8F\xA2\xB7|\e\(J[\x21-\x7E]*)/, $str;
    }
    my $utf8 = '';
    foreach my $s (@str) {
	unless (length $s) {
	    next;
	} elsif ($s =~ /^\e\(J([\x21-\x7E]*)/) {
	    $s = $1;
	    next unless length $s;
	    Encode::utf8_on($s);
	    $s =~ s/\x{005C}/\x{00A5}/g; # YEN SIGN
	    $s =~ s/\x{007E}/\x{203E}/g; # OVERLINE
	    $utf8 .= $s;
	} elsif (!$obj->{shiftEncoding} and $s eq "\x8F\xA2\xB7") {
	    $utf8 .= "\x{FF5E}"; # TILDE, fullwidth
	} else {
	    my $u;
	    if ($obj->{shiftEncoding}) {
		$u = Encode::decode('cp932', $s, $chk);
	    } else {
		$u = Encode::decode('eucJP-ms', $s, $chk);
	    }
	    ## Fullwidth characters not being “alternative names” of JIS.
	    $u =~ s/\x{FFE0}/\x{00A2}/g; # X0208:01-81 CENT SIGN
	    $u =~ s/\x{FFE1}/\x{00A3}/g; # X0208:01-82 POUND SIGN
	    $u =~ s/\x{FFE2}/\x{00AC}/g; # X0208:02-44 NOT SIGN
	    # Mappings to characters with different properties.
	    $u =~ s/\x{FFE3}/\x{203E}/g; # X0208:01-17 OVERLINE
	    $u =~ s/\x{2015}/\x{2014}/g; # X0208:01-29 EM DASH
	    $u =~ s/\x{2225}/\x{2016}/g; # X0208:01-34 DOUBLE VERTICAL LINE
	    $u =~ s/\x{FF0D}/\x{2212}/g; # X0208:01-61 MINUS SIGN
	    $u =~ s/\x{FF5E}/\x{301C}/g; # X0208:01-33 WAVE DAH
	    $u =~ s/\x{FFE5}/\x{00A5}/g; # X0208:01-79 YEN SIGN
	    $u =~ s/\x{FFE4}/\x{00A6}/g; # X0212:02-35 BROKEN BAR
	    $utf8 .= $u;
	}
    }
    return $utf8;
}

my $subchar = "\xA2\xAE"; # U+3013 GETA MARK
sub encode($$;$) {
    my ($obj, $utf8, $chk) = @_;
    # empty the input string in the stack so perlio is ok
    $_[1] = '' if $chk;
    my @utf8 = split(/([\x{001A}\x{00A5}\x{203E}])/, $utf8);
    my $octet = '';
    foreach my $u (@utf8) {
	unless (length $u) {
	    next;
	} elsif ($u eq "\x{001A}") { # Workaround for <subchar>.
	    $octet .= "\x1A";
	} elsif ($u eq "\x{00A5}") { # YEN SIGN
	    if ($obj->{shiftEncoding}) {
		$octet .= "\x81\x8F"; # X0208:01-79 YEN SIGN
	    } else {
		$octet .= "\xA1\xEF"; # X0208:01-79 YEN SIGN
	    }
	} elsif ($u eq "\x{203E}") { # OVERLINE
	    if ($obj->{shiftEncoding}) {
		$octet .= "\x81\x50"; # X0208:01-17 OVERLINE
	    } else {	
		$octet .= "\xA1\xB1"; # X0208:01-17 OVERLINE
	    }
	} else {
	    my $o;
	    if ($obj->{shiftEncoding}) {
		$o = Encode::encode('cp932', $u, $chk);
	    } else {
		$o = Encode::encode('eucJP-ms', $u, $chk);
	    }
	    $o =~ s/\x1A/$subchar/g;
	    $octet .= $o;
	}
    }
    if ($obj->{sevenBits}) {
	Encode::EUCJPMS::euc_jis(\$octet, 1);
    }
    return $octet;
}

1;
