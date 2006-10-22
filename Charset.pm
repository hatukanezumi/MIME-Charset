
package MIME::Charset;
use v5.8;

=head1 NAME

MIME::Charset - Charset Informations for MIME

=head1 SYNOPSIS

Getting charset informations:

    use MIME::Charset qw(:info);

    $benc = body_encoding("iso-8859-2"); # "Q"
    $cset = canonical_charset("ANSI X3.4-1968"); # "US-ASCII"
    $henc = header_encoding("utf-8"); # "S"
    $cset = output_charset("shift_jis"); # "ISO-2022-JP"

Translating text data:

    use MIME::Charset qw(:trans);

    ($text, $charset, $encoding) =
        header_encode(
           "\xc9\xc2\xc5\xaa\xc0\xde\xc3\xef\xc5\xaa".
           "\xc7\xd1\xca\xaa\xbd\xd0\xce\xcf\xb4\xef",
           "euc-jp");
    # ...returns (<converted>, "ISO-2022-JP", "B");

    ($text, $charset, $encoding) =
        body_encode(
            "Collectioneur path\xe9tiquement ".
            "\xe9clectique de d\xe9chets",
            "latin1");
    # ...returns (<original>, "ISO-8859-1", "QUOTED-PRINTABLE");

Manipulating package defaults:

    use MIME::Charset;

    MIME::Charset::alias("csEUCKR", "euc-kr");
    MIME::Charset::default("iso-8859-1");
    MIME::Charset::fallback("us-ascii");

=head1 DESCRIPTION

MIME::Charset provides informations about character sets used for
MIME messages on Internet.

=over 4

=cut

use strict;
use vars qw(@ISA $VERSION @EXPORT @EXPORT_OK %EXPORT_TAGS);
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(body_encoding canonical_charset header_encoding
		   output_charset body_encode header_encode);
@EXPORT_OK = qw(alias default fallback recommended);
%EXPORT_TAGS = (
		"info" => [qw(body_encoding header_encoding
			      canonical_charset output_charset)],
		"trans" =>[ qw(body_encode header_encode)],
);
use Carp qw(croak);

use Encode;

$VERSION = '0.02';

######## Private Attributes ########

my $DEFAULT_CHARSET = 'US-ASCII';
my $FALLBACK_CHARSET = 'UTF-8';

# This table is borrwed from Python email package.

my %CHARSETS = (# input		    header enc body enc output conv
		'ISO-8859-1' =>		['Q',	'Q',	undef],
		'ISO-8859-2' =>		['Q',	'Q',	undef],
		'ISO-8859-3' =>		['Q',	'Q',	undef],
		'ISO-8859-4' =>		['Q',	'Q',	undef],
		# ISO-8859-5 is Cyrillic, and not especially used
		# ISO-8859-6 is Arabic, also not particularly used
		# ISO-8859-7 is Greek, 'Q' will not make it readable
		# ISO-8859-8 is Hebrew, 'Q' will not make it readable
		'ISO-8859-9' =>		['Q',	'Q',	undef],
		'ISO-8859-10' =>	['Q',	'Q',	undef],
		# ISO-8859-11 is Thai, 'Q' will not make it readable
		'ISO-8859-13' =>	['Q',	'Q',	undef],
		'ISO-8859-14' =>	['Q',	'Q',	undef],
		'ISO-8859-15' =>	['Q',	'Q',	undef],
		'WINDOWS-1252' =>	['Q',	'Q',	undef],
		'VISCII' =>		['Q',	'Q',	undef],
		'US-ASCII' =>		[undef,	undef,	undef],
		'BIG5' =>		['B',	'B',	undef],
		'GB2312' =>		['B',	'B',	undef],
		'EUC-JP' =>		['B',	undef,	'ISO-2022-JP'],
		'SHIFT_JIS' =>		['B',	undef,	'ISO-2022-JP'],
		'ISO-2022-JP' =>	['B',	undef,	undef],
		'KOI8-R' =>		['B',	'B',	undef],
		'UTF-8' =>		['S',	'B',	undef],
		# We're making this one up to represent raw unencoded 8bit
		'8BIT' =>		[undef,	'B',	'ISO-8859-1'],
		);

# Fix some unexpected or unpreferred names returned by
# Encode::resolve_alias() or used by somebodies else.
my %CHARSET_ALIASES = (# unpreferred		preferred
		       "ASCII" =>		"US-ASCII",
		       "BIG5-ETEN" =>		"BIG5",
		       "CP1251" =>		"WINDOWS-1251",
		       "CP1252" =>		"WINDOWS-1252",
		       "CP936" =>		"GBK",
		       "CP949" =>		"KS_C_5601-1987",
		       "EUC-CN" =>		"GB2312",
		       "KS_C_5601" =>		"KS_C_5601-1987",
		       "SHIFTJIS" =>		"SHIFT_JIS",
		       "SHIFTJISX0213" =>	"SHIFT_JISX0213",
		       "UNICODE-1-1-UTF-7" =>	"UTF-7",
		       "UTF8" =>		"UTF-8",
		       );

# ISO-2022-* escape sequnces to detect charset from unencoded data.
my @ISO2022_SEQ = (# escape seq	possible charset
		   # Following sequences are commonly used.
		   ["\033\$\@",	"ISO-2022-JP"],	# RFC 1468
		   ["\033\$B",	"ISO-2022-JP"],	# ditto
		   ["\033(J",	"ISO-2022-JP"],	# ditto
		   ["\033(I",	"ISO-2022-JP"],	# ditto (nonstandard)
		   ["\033\$(D",	"ISO-2022-JP"],	# RFC 2237 (note*)
		   # Folloing sequences are less commonly used.
		   ["\033\$)C",	"ISO-2022-KR"],	# RFC 1557
		   ["\033\$)A",	"ISO-2022-CN"], # RFC 1922
		   ["\033\$A",	"ISO-2022-CN"], # ditto (nonstandard)
		   ["\033\$)G",	"ISO-2022-CN"], # ditto
		   ["\033\$*H",	"ISO-2022-CN"], # ditto
		   # Other sequences will be used with appropriate charset
		   # parameters, or hardly used.
		   );

		   # note*: This RFC defines ISO-2022-JP-1, superset of
		   # ISO-2022-JP.  But that charset name is rarely used.
		   # OTOH many of codecs for ISO-2022-JP recognize this
		   # sequence so that comatibility with EUC-JP will be
		   # guaranteed.

######## Private Constants ########

my $NONASCIIRE = qr{
    [^\x01-\x7e]
}x;

my $ISO2022RE = qr{
    ^ISO-2022-
}ix;


######## Public Functions ########

=head2 GETTING INFORMATIONS OF CHARSETS

=item body_encoding CHARSET

Get recommended transfer-encoding of CHARSET for message body.

Returned value is one of C<"B"> (BASE64), C<"Q"> (QUOTED-PRINTABLE) or
C<undef> (might not be transfer-encoded; either 7BIT or 8BIT).  This may
not be same as encoding for message header.

=cut

sub body_encoding($) {
    my $charset = shift;
    return undef unless $charset;
    return (&recommended($charset))[1];
}

=item canonical_charset CHARSET

Get canonical name for charset CHARSET.

=cut

sub canonical_charset($) {
    my $charset = shift;
    return undef unless $charset;
    my $cset = Encode::resolve_alias($charset) || $charset;
    return $CHARSET_ALIASES{uc($cset)} || uc($cset);
}

=item header_encoding CHARSET

Get recommended encoding scheme of CHARSET for message header.

Returned value is one of C<"B">, C<"Q">, C<"S"> (shorter one of either)
or C<undef> (might not be encoded).  This may not be same as encoding
for message body.

=cut

sub header_encoding($) {
    my $charset = shift;
    return undef unless $charset;
    return (&recommended($charset))[0];
}

=item output_charset CHARSET

Get a charset compatible with given CHARSET which is recommended to be
used for MIME messages on Internet (if it is known by this package).

=cut

sub output_charset($) {
    my $charset = shift;
    return undef unless $charset;
    return (&recommended($charset))[2] || uc($charset);
}

=head2 TRANSLATING TEXT DATA

=item body_encode STRING, CHARSET [, OPTS]

Get converted (if needed) data and recommended transfer-encoding of
that data for message body.  CHARSET is the charset by which STRING
is encoded.

OPTS may accept following key-value pairs:

=over 4

=item Replacement => REPLACEMENT

Specifies error handling scheme. See L<"ERROR HANDLING">.

=item Detect7bit => YESNO

Try auto-detecting 7-bit charset when CHARSET is not given.
Default is C<"YES">.

=back

3-item list of (I<converted string>, I<charset for output>,
I<transfer-encoding>) is returned.
I<Transfer-encoding> is either C<"BASE64">, C<"QUOTED-PRINTABLE">,
C<"7BIT"> or C<"8BIT">.  If I<charset for output> could not be determined
and I<converted string> contains non-ASCII byte(s), I<charset for output> is
C<undef> and I<transfer-encoding> is C<"BASE64">.  I<Charset for output> is
C<"US-ASCII"> if and only if string does not contain any non-ASCII bytes.

=cut

sub body_encode {
    my ($encoded, $charset, $cset) = &text_encode(@_);

    # Determine transfer-encoding.
    my $enc = &body_encoding($charset);
    if (!$enc and $encoded !~ /\x00/) {	# Eliminate hostile NUL character.
        if ($encoded =~ $NONASCIIRE) {	# String contains 8bit char(s).
            $enc = '8BIT';
	} elsif ($cset =~ $ISO2022RE) {	# ISO-2022-* outputs are 7BIT.
            $enc = '7BIT';
        } else {			# Pure ASCII.
            $enc = '7BIT';
            $cset = 'US-ASCII';
        }
    } elsif ($enc eq 'B') {
        $enc = 'BASE64';
    } elsif ($enc eq 'Q') {
        $enc = 'QUOTED-PRINTABLE';
    } else {
        $enc = 'BASE64';
    }
    return ($encoded, $cset, $enc);
}

=item header_encode STRING, CHARSET [, OPTS]

Get converted (if needed) data and recommended encoding scheme of
that data for message headers.  CHARSET is the charset by which STRING
is encoded.

OPTS may accept following key-value pairs:

=over 4

=item Replacement => REPLACEMENT

Specifies error handling scheme. See L<"ERROR HANDLING">.

=item Detect7bit => YESNO

Try auto-detecting 7-bit charset when CHARSET is not given.
Default is C<"YES">.

=back

3-item list of (I<converted string>, I<charset for output>,
I<encoding scheme>) is returned.  I<Encoding scheme> is either C<"B">,
C<"Q"> or C<undef> (might not be encoded).  If I<charset for output>
could not be determined and I<converted string> contains non-ASCII byte(s),
I<charset for output> is C<"8BIT"> (this is I<not> charset name but a
special value to represent unencodable data) and I<encoding scheme> is
C<undef> (shouldn't be encoded).  I<Charset for output> is C<"US-ASCII">
if and only if string doesn't contain any non-ASCII bytes.

=back

=cut

sub header_encode {
    my ($encoded, $charset, $cset) = &text_encode(@_);
    return ($encoded, '8BIT', undef) unless $cset;

    # Determine encoding scheme.
    my $enc = &header_encoding($charset);
    if (!$enc and $encoded !~ $NONASCIIRE) {
	unless ($cset =~ $ISO2022RE) {	# ISO-2022-* outputs are 7BIT.
            $cset = 'US-ASCII';
        }
    } elsif ($enc eq 'S') {
	if (length(Encode::encode("MIME-B", $encoded)) <
	    length(Encode::encode("MIME-Q", $encoded))) {
	    $enc = 'B';
	} else {
	    $enc = 'Q';
	}
    } elsif ($enc !~ /^[BQ]$/) {
        $enc = 'B';
    }
    return ($encoded, $cset, $enc);
}

sub text_encode {
    my $s = shift;
    my $charset = &canonical_charset(shift);
    my %params = @_;
    my $replacement = uc($params{'Replacement'}) || "DEFAULT";
    my $detect7bit = uc($params{'Detect7bit'}) || "YES";

    if (!$charset) {
	if ($s =~ $NONASCIIRE) {
	    return ($s, undef, undef);
	} elsif ($detect7bit ne "NO") {
	    $charset = &detect_7bit_charset($s);
	} else {
	    $charset = $DEFAULT_CHARSET;
	} 
    }

    # Unknown charset.
    return ($s, $charset, $charset)
	unless Encode::resolve_alias($charset);

    # Encode data by output charset if required.  If failed, fallback to
    # fallback charset.
    my $cset = &output_charset($charset);
    my $encoded;

    if (Encode::is_utf8($s)) {
	if ($replacement =~ /^(?:CROAK|STRICT|FALLBACK)$/) {
	    eval {
		$encoded = Encode::encode($cset, $s, $Encode::FB_CROAK);
	    };
	    if ($@) {
		if ($replacement eq "FALLBACK" and $FALLBACK_CHARSET) {
		    $cset = $FALLBACK_CHARSET;
		    $encoded = Encode::encode($cset, $s);
		    $charset = $cset;
		} else {
		    croak $@;
		}
	    }
	} elsif ($replacement eq "PERLQQ") {
	    $encoded = Encode::encode($cset, $s, $Encode::FB_PERLQQ);
	} elsif ($replacement eq "HTMLCREF") {
	    $encoded = Encode::encode($cset, $s, $Encode::FB_HTMLCREF);
	} elsif ($replacement eq "XMLCREF") {
	    $encoded = Encode::encode($cset, $s, $Encode::FB_XMLCREF);
	} else {
	    $encoded = Encode::encode($cset, $s);
	}
    } elsif ($charset ne $cset) {
	$encoded = $s;
	if ($replacement =~ /^(?:CROAK|STRICT|FALLBACK)$/) {
	    eval {
		&Encode::from_to($encoded, $charset, $cset, $Encode::FB_CROAK);
	    };
	    if ($@) {
		if ($replacement eq "FALLBACK" and $FALLBACK_CHARSET) {
		    $cset = $FALLBACK_CHARSET;
		    Encode::from_to($encoded, $charset, $cset);
		    $charset = $cset;
		} else {
		    croak $@;
		}
	    }
        } elsif ($replacement eq "PERLQQ") {
            Encode::from_to($encoded, $charset, $cset,
				       $Encode::FB_PERLQQ);
        } elsif ($replacement eq "HTMLCREF") {
            Encode::from_to($encoded, $charset, $cset,
				       $Encode::FB_HTMLCREF);
        } elsif ($replacement eq "XMLCREF") {
            Encode::from_to($encoded, $charset, $cset,
				       $Encode::FB_XMLCREF);
        } else {
            Encode::from_to($encoded, $charset, $cset);
        }
    } else {
        $encoded = $s;
    }

    return ($encoded, $charset, $cset);
}

sub detect_7bit_charset($) {
    my $s = shift;
    return $DEFAULT_CHARSET unless $s;

    # Try to detect ISO-2022-* escape sequences.
    foreach (@ISO2022_SEQ) {
	my ($seq, $cset) = @$_;
	if (index($s, $seq) >= 0) {
            eval {
		my $dummy = Encode::decode($cset, $s, $Encode::FB_CROAK);
	    };
	    if ($@) {
		next;
	    }
	    return $cset;
	}
    }

    # How about HZ, VIQR, ...?

    return $DEFAULT_CHARSET;
}

=head2 MANUPULATING PACKAGE DEFAULTS

=over 4

=item alias ALIAS [, CHARSET]

Get/set charset alias for canonical names determined by
L<canonical_charset>.

If CHARSET is given and not false, ALIAS is assigned as an alias of
CHARSET.  Otherwise, alias is not changed.  In both cases, this
function returns current charset name that ALIAS is assigned.

=cut

sub alias ($;$) {
    my $alias = uc(shift);
    my $charset = uc(shift);

    return $CHARSET_ALIASES{$alias} unless $charset;

    $CHARSET_ALIASES{$alias} = $charset;
    return $charset;
}

=item default [CHARSET]

Get/set default charset.

B<Default charset> is used by this package when charset context is
unknown.  Modules using this package are recommended to use this
charset when charset context is unknown or implicit default is
expected.  By default, it is C<"US-ASCII">.

If CHARSET is given and not false, it is set to default charset.
Otherwise, default charset is not changed.  In both cases, this
function returns current default charset.

B<NOTE>: Default charset I<should not> be changed.

=cut

sub default(;$) {
    my $charset = &canonical_charset(shift);

    if ($charset) {
	croak "Unknown charset '$charset'"
	    unless Encode::resolve_alias($charset);
	$DEFAULT_CHARSET = $charset;
    }
    return $DEFAULT_CHARSET;
}

=item fallback [CHARSET]

Get/set fallback charset.

B<Fallback charset> is used by this package when conversion by given
charset is failed and C<"FALLBACK"> error handling scheme is specified.
Modules using this package may use this charset as last resort of charset
for conversion.  By default, it is C<"UTF-8">.

If CHARSET is given and not false, it is set to fallback charset.
If CHARSET is C<"NONE">, fallback charset become undefined.
Otherwise, fallback charset is not changed.  In any cases, this
function returns current fallback charset.

B<NOTE>: It I<is> useful that C<"US-ASCII"> is specified as fallback charset,
since result of conversion will be readable without charset informations.

=cut

sub fallback(;$) {
    my $charset = &canonical_charset(shift);

    if ($charset eq "NONE") {
	$FALLBACK_CHARSET = undef;
    } elsif ($charset) {
	croak "Unknown charset '$charset'"
	    unless Encode::resolve_alias($charset);
	$FALLBACK_CHARSET = $charset;
    }
    return $FALLBACK_CHARSET;
}

=item recommended CHARSET [, HEADERENC, BODYENC [, ENCCHARSET]]

Get/set charset profiles.

If optional arguments are given and any of them are not false, profiles
for CHARSET is set by those arguments.  Otherwise, profiles
won't be changed.  In both cases, current profiles for CHARSET are
returned as 3-item list of (HEADERENC, BODYENC, ENCCHARSET).

HEADERENC is recommended encoding scheme for message header.
It may be one of C<"B">, C<"Q">, C<"S"> (shorter one of either) or
C<undef> (might not be encoded).

BODYENC is recommended transfer-encoding for message body.  It may be
one of C<"B">, C<"Q"> or C<undef> (might not be transfer-encoded).

ENCCHARSET is compatible with given CHARSET and is recommended to be
used for MIME messages on Internet.  If conversion is not needed
(or this package doesn't know appropriate charset), ENCCHARSET is
C<undef>.

B<NOTE>: This function in the future releases can accept more optional
arguments (for example, properties to handle character widths, line folding
behavior, ...).  So format of returned value may probably be changed.
Use L<header_encoding>, L<body_encoding> or L<output_charset> to get
particular profile.

=cut

sub recommended ($;$;$;$) {
    my $charset = &canonical_charset(shift);
    my $henc = uc(shift) || undef;
    my $benc = uc(shift) || undef;
    my $cset = &canonical_charset(shift);

    croak "CHARSET is not specified" unless $charset;
    croak "Unknown header encoding" unless !$henc or $henc =~ /^[BQS]$/;
    croak "Unknown body encoding" unless !$benc or $benc =~ /^[BQ]$/;

    if ($henc or $benc or $cset) {
	$cset = undef if $charset eq $cset;
	my @spec = ($henc, $benc, $cset);
	$CHARSETS{$charset} = \@spec;
	return @spec;
    } else {
	my $spec = $CHARSETS{$charset};
	if ($spec) {
	    return ($$spec[0], $$spec[1], $$spec[2]);
	} else {
	    return ('S', 'B', undef);
	}
    }
}

=head2 ERROR HANDLING

L<body_encode> and L<header_encode> accept following C<Replacement>
options:

=item C<"DEFAULT">

Put a substitution character in place of a malformed character.
For UCM-based encodings, <subchar> will be used.

=item C<"FALLBACK">

Try C<"DEFAULT"> scheme using I<fallback charset> (see L<fallback>).
When fallback charset is undefined and conversion causes error,
code will die on error with an error message.

=item C<"CROAK">

Code will die on error immediately with an error message.
Therefore, you should trap the fatal error with eval{} unless you
really want to let it die on error.
Synonym is C<"STRICT">.

=item C<"PERQQ">

=item C<"HTMLCREF">

=item C<"XMLCREF">

Use L<Encode/FB_PERLQQ>, L<Encode/FB_HTMLCREF> or L<Encode/FB_XMLCREF>
scheme defined by L<Encode> module.

=back

If error handling scheme is not specified or unknown scheme is specified,
C<"DEFAULT"> will be assumed.

=head1 SEE ALSO

Multipurpose Internet Mail Extensions (MIME).

=head1 COPYRIGHT

Copyright (C) 2006 Hatuka*nezumi - IKEDA Soji <F<hatuka@nezumi.nu>>.
All rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of either:

a) the GNU General Public License as published by the Free Software
Foundation; either version 2, or (at your option) any later version,

or

b) the "Artistic License" which comes with this module.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
the GNU General Public License or the Artistic License for more details.

You should have received a copy of the Artistic License with this
module, in the file ARTISTIC.  If not, I'll be glad to provide one.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
USA.

=cut

1;
