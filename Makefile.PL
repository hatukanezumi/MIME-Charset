use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'		=> 'MIME::Charset',
	'ABSTRACT_FROM'	=> 'Charset.pm',
	'VERSION_FROM'	=> 'Charset.pm',
	'PREREQ_PM'	=> {
	    'Carp'		=> 0,
	    'Encode'		=> 0,
	    #'Test::More'	=> 0,
	},
);

