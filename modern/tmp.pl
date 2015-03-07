#!/bin/env perl

use strict;
use warnings;
#use diagnostics;
use lib 'lib';

## change these:
my $uid = 123;
my $gid = 123;

BEGIN {
	$ENV{EXT_INTERCHANGE_DIR}     ||= '/path/to/interchange/server';
	$ENV{EXT_INTERCHANGE_CATALOG} ||= 'catalog_name';
}

## chuser if root
use POSIX qw(setuid setgid);
my $user = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
if ($user eq 'root') {
	setuid($uid);
	setgid($gid);
}

## setup IC environment
use Vend::External;
session();
chdir $Vend::Cfg->{VendRoot}
	or die "Unable to chdir $Vend::Cfg->{VendRoot}: $!\n";

## do stuff
use Vend::MyModule;

my $m = Vend::MyModule->new();

print $m->_is_username('josh');
