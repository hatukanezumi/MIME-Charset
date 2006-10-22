use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'		=> 'MIME::Charset',
	'ABSTRACT_FROM'	=> 'Charset.pm',
	'VERSION_FROM'	=> 'Charset.pm',
	'PREREQ_PM'	=> {
	    'Encode'		=> 2.01,
	    'Test::More'	=> 0,
	},
);

