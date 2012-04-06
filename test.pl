#!/usr/bin/env perl
exec("perl Makefile.PL && prove -Ilib -r t/");
