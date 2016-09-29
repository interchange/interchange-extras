#!/bin/env perl

use Modern::Perl '2010';
#use diagnostics;
use lib 'lib';

use Vend::MyModule;

my $m = Vend::MyModule->new();

$m->log('test');
