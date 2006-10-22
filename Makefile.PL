use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'		=> 'MIME::Charset',
	'ABSTRACT_FROM'	=> 'Charset.pm',
	'VERSION_FROM'	=> 'Charset.pm',
	'PREREQ_PM'	=> ($] >= 5.008001)? {
	    'Encode'	=> 1.98,
	    'Test'	=> 0,
	}: {
	    'Test'	=> 0,
	},
);

