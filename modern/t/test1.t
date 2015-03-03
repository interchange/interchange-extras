#!/bin/env perl

use strict;
use warnings;
use lib 'lib';

## change these:
my $uid = 123;
my $gid = 123;
my $catname = 'my_catalog';

## set path to IC server as an environment variable:
##    EXT_INTERCHANGE_DIR=/path/to/interchange/server
##
$ENV{EXT_INTERCHANGE_CATALOG} ||= $catname;

## chuser if root
use POSIX qw(setuid setgid);
my $user = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
if ($user eq 'root') {
	setuid($uid);
	setgid($gid);
}

use Vend::External;
session();
chdir $Vend::Cfg->{VendRoot}
	or die "Unable to chdir $Vend::Cfg->{VendRoot}: $!\n";

use Vend::MyModule;

use Test::Simple tests => 1;

my $m = Vend::MyModule->new();

## your tests here
ok( 1, "1 is 1");
