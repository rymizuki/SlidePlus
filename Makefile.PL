use strict;
use warnings;

use inc::Module::Install;

name 'SlidePlus';
all_from 'lib/SlidePlus.pm';
license 'ry_mizuki';

build_requires 'Test::LoadAllModules';

requires 'Config::Pit';
requires 'Data::Page';
requires 'Data::Validator';
requires 'DateTimeX::Factory';
requires 'DBIx::Sunny::Schema';
requires 'DBIx::QueryLog';
requires 'Exporter::Lite';
requires 'JSON';
requires 'LWP::UserAgent';
requires 'Mouse';
requires 'OAuth::Lite::Consumer';
requires 'parent';
requires 'Scope::Container';
requires 'Scope::Container::DBI';
requires 'String::Random';
requires 'Text::Xatena';

WriteAll;
