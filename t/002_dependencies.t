use strict;
use warnings;
use Test::Module::Used;

my $used = Test::Module::Used->new(
    lib_dir     => ['lib'],
    meta_file   => 'MYMETA.yml',
);
$used->push_exclude_in_libdir(qw(-norequire));
$used->ok;
