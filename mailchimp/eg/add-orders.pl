#!/bin/env perl

use strict;
use warnings;
use lib 'lib';
use v5.14;

#
# Sample script to add *past* e-commerce orders to MailChimp
# See the "modern" directory for MyModule.pm
# YMMV.
#

BEGIN {
   $ENV{EXT_INTERCHANGE_DIR}     = '/path/to/interchange';
   $ENV{EXT_INTERCHANGE_CATALOG} = 'your-catalog';
}

use Vend::External;
use Vend::MyModule;
use Ext::MailChimp3;
use JSON;
use Devel::Dwarn;

my $mc = Ext::MailChimp3->new(
    api_key  => 'YOUR-KEY-HERE',
    debug    => 0,
    store_id => 'YOUR-STORE-ID-HERE',
);

my $ic = Vend::MyModule->new();

#my $orders = $mc->do('orders', { fields => 'orders.id', store_id => $mc->store_id, count => 999999 } );
#print scalar @$orders;
#$mc->do('batch', { batch_id => '' } );
#__END__

my $dbh = $ic->dbh('transactions');
my $orders = $dbh->selectall_arrayref(
    q{
        SELECT
            t.code,
            t.username,
            t.total_cost,
            t.salestax,
            t.shipping,
            t.order_date,
            u.email,
            u.fname,
            u.lname
        FROM transactions t, userdb u
        WHERE t.username = u.username
        AND t.status != 'canceled'
        AND t.order_date LIKE ?
    },
    { Slice => {} },
    '201609%',
);
my $sth = $dbh->prepare_cached(q{
    SELECT
        code AS id,
        sku AS product_id,
        sku AS product_variant_id,
        quantity,
        price
    FROM orderline
    WHERE order_number = ?
});

my $batches = [];

for my $order (@$orders) {
    $order->{order_date} =~ s/(\d\d\d\d)(\d\d)(\d\d)/$1-$2-$3/;
    my $customer = {
        id            => $order->{username},
        email_address => $order->{email},
        opt_in_status => 0,   # won't overwrite pre-existing subscribers
        first_name    => $order->{fname},
        last_name     => $order->{lname},
    };
    my $lines = $dbh->selectall_arrayref( $sth, { Slice => {} }, $order->{code} );
    my $body = {
        id                   => $order->{code},
        customer             => $customer,
        currency_code        => 'USD',
        order_total          => $order->{total_cost},
        tax_total            => $order->{salestax},
        shipping_total       => $order->{shipping},
        processed_at_foreign => $order->{order_date},
        lines                => $lines,
    };
    $body = $mc->_massage_options($body);
#Dwarn $body;
#last;
    push @$batches, {
        method       => 'POST',
        path         => '/ecommerce/stores/' . $mc->store_id . '/orders',
        body         => encode_json $body,
        operation_id => $order->{code},
    };
}

#Dwarn $orders;
#Dwarn $batches;
#say scalar @$batches;

#$mc->do('add_batch', { operations => $batches } );
