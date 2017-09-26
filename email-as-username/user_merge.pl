use strict;
use warnings;
use 5.14.1;

use FooCorp::Config use_libs => 1;
use FooCorp::UserMerge;
use Data::Dumper;

my $merge = FooCorp::UserMerge->new;
#say Dumper $merge;

#say Dumper $merge->_dupe_emails;

#$merge->merge_dupe_email_users;
