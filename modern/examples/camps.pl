#!/bin/env perl

use strict;
use warnings;

use Camp::Config use_libs => 1;

BEGIN {
    $ENV{EXT_INTERCHANGE_DIR}     ||= Camp::Config->ic_path();
    $ENV{EXT_INTERCHANGE_RUNDIR}  ||= Camp::Config->ic_path() . '/var/run';
    $ENV{EXT_INTERCHANGE_CATALOG} ||= Camp::Config->catalog();
}

use Vend::External;
use Vend::MyModule;

my $m = Vend::MyModule->new();

print $m->_is_username('josh');
