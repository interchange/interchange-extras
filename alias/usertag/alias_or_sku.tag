UserTag alias_or_sku Order sku
UserTag alias_or_sku Routine <<EOR
sub {
    my $sku = shift; 

    my $db = dbref('alias')
        or return $sku;

    my $dbh = $db->dbh();

    my $alias = $dbh->selectrow_array(
        q{
            SELECT alias
            FROM alias
            WHERE real_page = ?
            ORDER BY mod_time DESC
        },
        undef,
        $sku
    );

    return $alias || $sku;
}
EOR
UserTag alias_or_sku Documentation <<EOD

Will automatically link with the alias if it exists, with fallback to the SKU.

Usage:

Before: <a href="[area [item-code]]">Product link</a>
After:  <a href="[area href="[alias_or_sku [item-code]]"]">Product link</a>

EOD
