UserTag  mailchimp360  addAttr
UserTag  mailchimp360  Routine <<EOR
sub {
    my ($opt) = @_;

    use vars qw/$Tag/;

    my $cid_cookie_name = 'MV_MAILCHIMP_CAMPAIGN_ID';
    my $eid_cookie_name = 'MV_MAILCHIMP_EMAIL_ID';

##    
##    SUB: Create cookie
##
    my $set = sub {
        my ($cookie_name, $cookie_value) = @_;
        my $expire = $opt->{expire} || '30 days';
        my $domain = $opt->{domain} || '';
        my $path   = $opt->{path}   || '';

        Vend::Util::set_cookie($cookie_name,$cookie_value,$expire,$domain,$path);
    };

##
##  Look for MailChimp params or cookies, otherwise return
##
    if ( $CGI::values{mc_cid} && $CGI::values{mc_eid} ) {
#::logDebug("mc360: found mc_cid and mc_eid");
        my $cid = $Tag->filter('encode_entities', $CGI::values{mc_cid});
        my $eid = $Tag->filter('encode_entities', $CGI::values{mc_eid});
        $set->($cid_cookie_name, $cid);
        $set->($eid_cookie_name, $eid);

        ## store in session, so cart_abandon can get at it later
        $Session->{mailchimp_eid} = $eid; 
    }
    elsif ($opt->{order}) {
        # move on
    }
    else {
        ## store in session if not already there.
#::logDebug("mc360: nothing asked of us.");
        if (! $Session->{mailchimp_eid}) {
            my $eid = Vend::Util::read_cookie($eid_cookie_name);
            $Session->{mailchimp_eid} = $eid if $eid; 
#::logDebug("mc360: setting session for: $eid");
        }
    }

##
##  Record Order
##
    if ($opt->{order}) {
        my $campaign_id = $opt->{campaign_id}   || Vend::Util::read_cookie($cid_cookie_name);
        my $email_id    = $opt->{email_address} || Vend::Util::read_cookie($eid_cookie_name) || $::Values->{email};
        my $store_id    = $opt->{store_id}      || $::Variable->{MAILCHIMP_STORE_ID};
        unless ( $email_id and $store_id ) {
            return $opt->{show}
                ? die 'mailchimp360 called without required parameters of: email_id, store_id'
                : undef;
        }

        my $cart_name     = $opt->{cart_name} || 'main';
        my $carts         = $Vend::Session->{carts};
        my $currency_code = ( $Vend::Cfg->{Locale} and $Vend::Cfg->{Locale}{int_curr_symbol} ) || 'USD';
        $currency_code =~ s/\s//g;
        my @items;

        my $i = 0;
        for my $it ( @{$carts->{$cart_name}} ) {
            my $sku         = $it->{mv_sku} || $it->{code};
            my $variant_sku = $it->{code}   || $it->{mv_sku};
            push @items, {
                id                 => 'item' . $i++,
                product_id         => $sku,
                product_variant_id => $variant_sku,
                quantity           => $it->{quantity},
                price              => Vend::Interpolate::product_price( $it->{code}, 1, $it->{mv_ib} ),
            };
        }
        return unless scalar @items;
#::logDebug("mc360: items=" . ::uneval(\@items));

        my $mc_data = {
            method   => 'add_order',
            store_id => $store_id,
            id       => $::Values->{mv_order_number} || POSIX::strftime( '%Y%m%d%H%M%S', localtime ),
            customer => {
                id => $::Session->{username} || $email_id,
                email_address => $email_id,
                opt_in_status => $opt->{optin} || 0,
                first_name    => $::Values->{fname},
                last_name     => $::Values->{lname},
            },
            campaign_id    => $campaign_id,
            currency_code  => $currency_code,
            order_total    => Vend::Interpolate::total_cost(),
            tax_total      => Vend::Interpolate::salestax(),
            shipping_total => $Tag->shipping( { noformat => 1 } ),
            processed_at_foreign => POSIX::strftime( '%F %T', localtime ),
            lines                => \@items,
            hide                 => !$opt->{show},
            queue => defined $opt->{queue} ? $opt->{queue} : 1,
            debug => $opt->{debug},
        };
#::logDebug("mc data: " . ::uneval($mc_data) );

        my $status = $Tag->mailchimp( $mc_data );
#::logDebug("mc360 status: " . $status);
        return $status if $opt->{show};
    }

    return;
}
EOR

Usertag  mailchimp360  Documentation <<EOD

=head1 NAME

mailchimp360 -- sends e-commerce orders back to MailChimp

=head1 DESCRIPTION

Implements the MailChimp 360 plugin for Interchange. 

This will only work for existing subscribers.

Options:

=over 4

=item order

Set to 1 if you need to record an order. This is usually done near the bottom of F<CATROOT/etc/receipt.html>, with this:

    [mailchimp360 order=1]

=item optin

Set to 1 to opt-in the customer to emails. Only affects new list members.

=item queue

On by default, set to 0 to disable.

=item debug

Set to 1 to enable MailChimp debugging.

=back

Usage:

=over 4

Add this to F<CATROOT/catalog.cfg>:

    Autoload [mailchimp360]

=back

Testing:

=over 4

Send a test campaign to yourself with the "Ecommerce 360" tags (under
Advanced Tracking options). Click a link, and submit an order.

Additionally, you can uncomment the logDebug lines, and watch the debug
log when placing an order. As a last resort, make sure you are getting
the special MailChimp cookies assigned by Interchange.

=back

=head1 PREREQUISITES

mailchimp.tag

=head1 BUGS

The usual number.

=head1 COPYRIGHT

Copyright (C) 2012-2016 Josh Lavin. All rights reserved.

This usertag is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Josh Lavin - End Point Corp.

EOD
