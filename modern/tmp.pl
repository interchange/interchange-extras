#!/bin/env perl

use Modern::Perl '2010';

BEGIN {
	$ENV{EXT_INTERCHANGE_DIR}     ||= '/path/to/interchange/server';
	$ENV{EXT_INTERCHANGE_CATALOG} ||= 'catalog_name';
}

use lib 'lib';
use Vend::External;
use Vend::MyModule;

my $m = Vend::MyModule->new();

say $m->_is_username('josh');
