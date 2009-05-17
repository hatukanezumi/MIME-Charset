use strict;
use Test::More;
eval "use Pod::Simple 2.06";
if ($@) {
    plan skip_all => "Pod::Simple 2.05 or later required for testing POD";
} else {
    eval "use Test::Pod 1.00";
    if ($@) {
        plan skip_all => "Test::Pod 1.00 or later required for testing POD";
    }
}
all_pod_files_ok();

