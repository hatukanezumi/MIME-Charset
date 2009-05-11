#-*- perl -*-

use inc::Module::Install;

# Define metadata
all_from 'Charset.pm';
license 'perl';
check_nmake;

# Specific dependencies
test_requires 'Test::More' => '0';
if ( $] >= 5.008 ) {
    requires 'Encode' => '1.98';
    include 'Module::AutoInstall';
    feature 'Extended mappings by Japanese codepages',
      -default          => 0,
      'Encode::EUCJPMS' => '0.06';
    feature 'Additional mappings for JIS X 0213:2000',
      -default        => 0,
      'Encode::JIS2K' => '0.02';
    feature 'Additional mappings for Chinese standards',
      -default           => 0,
      'Encode::HanExtra' => '0.20';
}

# Write out
no_index directory => 't', 'inc';
auto_install force => 0, do_once => 1;
WriteAll;

