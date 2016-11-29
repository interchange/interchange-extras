UserTag mailchimp Order method
UserTag mailchimp addAttr
UserTag mailchimp Alias mailchimp3
UserTag mailchimp Routine <<EOR
use Ext::MailChimp3;
sub {
    my ($method, $opt) = @_;
    my $mc = Ext::MailChimp3->new(
        api_key        => $::Variable->{MAILCHIMP_API_KEY},
        store_id       => $opt->{store_id} || $::Variable->{MAILCHIMP_STORE_ID} || undef,
        debug          => delete $opt->{debug},
        hide           => delete $opt->{hide},
        products_table => $Vend::Cfg->{ProductFiles}[0],
        desc_field     => $Vend::Cfg->{DescriptionField},
        price_field    => $Vend::Cfg->{PriceField},
        vendor_field   => $Vend::Cfg->{CategoryField},
        variants_table => $Vend::Cfg->{ProductFiles}[1],
    );

    delete $opt->{queue}
        and return $mc->queue( $method, $opt );

    $opt->{create_products}
        and return $mc->create_products();

    delete $opt->{$_} for qw/ method reparse /;    # get rid of stuff in opt we don't want

#::logDebug('passing to mc with opt: ' . ::uneval($opt) );

    my $result = $mc->do( $method, $opt );
    return $mc->hide ? undef : ::uneval($result);
}
EOR
