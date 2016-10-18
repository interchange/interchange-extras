UserTag alias_remove_dupes Routine <<EOR
sub {
    my $db = dbref('alias')
        or return;
    my $rdb = dbref('redirects')
        or return;

    my $dbh = $db->dbh();
    my $rdbh = $rdb->dbh();

    my $ary = $dbh->selectall_arrayref(
        q{
            SELECT *
            FROM alias
            ORDER BY real_page, mod_time DESC
        },
        { Slice => {} },
    );

    my $skus = {};
    for my $row (@$ary) {
        my $sku = $row->{real_page};
        $skus->{$sku} ||= [];
        push @{ $skus->{$sku} }, $row;
    }

    # remove entries with no duplication
    scalar @{ $skus->{$_} } < 2 and delete $skus->{$_} for keys %$skus;

    # build hashref of new links, and also removes the most-recent alias, leaving the dupes
    my $new_links = {};
    while (my ($k,$v) = each %$skus) {
        my $most_recent = shift @$v;
        $new_links->{$k} = $most_recent->{alias};
    }

    # all duplicates in a single array
    my $dupes = [];
    push @$dupes, @$_ for values %$skus;

    my $sth = $rdbh->prepare(q{
        REPLACE INTO redirects (
            old_link,
            new_link
        )
        VALUES ( ?, ? )
    });

    my $sth2 = $rdbh->prepare(q{
        DELETE FROM alias
        WHERE alias = ?
    });

    my @out;
    for my $alias (@$dupes) {
        my $result = $sth->execute( $alias->{alias}, $new_links->{ $alias->{real_page} } )
            or push @out, sprintf 'FAILURE to insert for: %s. %s', $alias->{alias}, $rdbh->errstr;
        next unless $result;

        my $result2 = $sth2->execute( $alias->{alias} )
            or push @out, sprintf 'FAILURE to delete for: %s. %s', $alias->{alias}, $rdbh->errstr;
        next unless $result2;

        push @out, sprintf 'Moved alias to redirects: %s', $alias->{alias};
    }
    return join "\n", @out;
}
EOR
UserTag alias_remove_dupes Documentation <<EOD

Requires the "redirects" feature.

EOD
