package FooCorp::UserMerge;

use strict;
use warnings;

use FooCorp::Config;

sub new {
    my $class = shift;
    my $self = {
        dbh          => FooCorp::Config->dbh(),
        merge_tables => 'transactions, orderline, carts, payment, wishlist, a_orderline, a_transactions',
    };
    my $object = bless $self, $class;
    $object->_set_dupe_users_sth;
    $object->_set_merge_queries;
    $object->_set_merge_to_sth;
    return $object;
}

sub merge_dupe_email_users {
    my $self = shift;
    my $dupes = $self->_dupe_emails;
    for my $email (@$dupes) {
        my $dupe_users = $self->{dbh}->selectcol_arrayref( $self->{sth_dupe_users}, {}, $email );
        my $master_user = shift @$dupe_users;
        for my $dupe (@$dupe_users) {
            my $m1 = $self->user_merge( $dupe, $master_user );
            my $m2 = $self->merge_tables( $dupe, $master_user );
            $m1 and warn $m1;
            $m2 and warn $m2;
        }
    }
    return;
}

sub user_merge {
    my ($self, $from, $to) = @_;
    $self->{sth_merge_to}->execute( $to, $from )
        or return sprintf 'could not set merge_to for: %s, merge to: %s', $from, $to;
    return;
}

sub merge_tables {
    my ($self, $from, $to) = @_;
    while ( my ($table, $sth) = each %{$self->{merge_queries}} ) {
        $sth->execute( $to, $from )
            or return sprintf 'could not merge tables for: %s, merge to: %s', $from, $to;
    }
    return sprintf 'performed merge from: %s, to: %s', $from, $to;
}

sub _dupe_emails {
    my $self = shift;
    my $q = q{
        SELECT LOWER(email)
        FROM userdb
        WHERE username NOT RLIKE '^[UVW][[:digit:]][[:digit:]]'
        AND COALESCE(email,'') <> ''
        AND merge_to IS NULL
        GROUP BY email
        HAVING COUNT(*) > 1
        ORDER BY 1
    };
    return $self->{dbh}->selectcol_arrayref($q);
}

sub _set_dupe_users_sth {
    my $self = shift;
    $self->{sth_dupe_users} = $self->{dbh}->prepare_cached(q{
        SELECT username
        FROM userdb
        WHERE email = ?
        AND username NOT RLIKE '^[UVW][[:digit:]][[:digit:]]'
        ORDER BY mod_time DESC
    });
}

sub _set_merge_queries {
    my $self = shift;
    my @tables = split  /[\s,\0]+/, $self->{merge_tables};
    my %queries;
    for my $table (@tables) {
        $queries{$table} = $self->{dbh}->prepare_cached(qq{
            UPDATE $table
            SET username = ?
            WHERE username = ?
        });
    }
    $self->{merge_queries} = \%queries;
}

sub _set_merge_to_sth {
    my $self = shift;
    $self->{sth_merge_to} = $self->{dbh}->prepare_cached(q{
        UPDATE userdb
        SET merge_to = ?
        WHERE username = ?
    });
}

1;
