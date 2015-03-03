#!/bin/env perl

use strict;
use warnings;
#use diagnostics;
use lib 'lib';

use Vend::MyModule;

my $m = Vend::MyModule->new();

$m->log('test');
