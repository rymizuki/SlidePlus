use strict;
use warnings;
use lib qw/lib/;

use Test::LoadAllModules;

BEGIN {
    all_uses_ok(
        search_path => 'SlidePlus',
        except  => [
        ],
    );
}
