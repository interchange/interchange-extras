package Ext::MailChimp3;

use 5.020000;
use Moo;
use strictures 2;
use namespace::autoclean;
use feature 'signatures';
no warnings qw(experimental::signatures);

use Types::Standard qw/ Str Bool InstanceOf /;
use Vend::Interpolate;
use Ext::OurTags;
use Mail::Chimp3;
use JSON;
use Digest::MD5 qw/ md5_hex /;

=head1 SYNOPSIS

This integrates the Mail::Chimp3 CPAN module with Interchange. It is
intended to be used with the C<[mailchimp]> usertag.

Please refer to the Perl documentation for L<Mail::Chimp3> as well.

=head1 METHODS

=head2 Constructor

=head3 MailChimp->new(...)

Accepts parameters: "api_key", "debug".

=over

=item * api_key

Your MailChimp API key.

=cut

has api_key => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

=item * store_id

Your MailChimp Store ID, from the L<Mail::Chimp3> C<stores> method.

=cut

has store_id => (
    is => 'ro',
);

has products_table => ( is => 'ro', default => $Vend::Cfg->{ProductFiles}[0]  || 'products', );
has desc_field     => ( is => 'ro', default => $Vend::Cfg->{DescriptionField} || 'description', );
has price_field    => ( is => 'ro', default => $Vend::Cfg->{PriceField}       || 'price', );
has vendor_field   => ( is => 'ro', default => $Vend::Cfg->{CategoryField}    || 'category', );
has variants_table => ( is => 'ro', default => $Vend::Cfg->{ProductFiles}[1]  || 'variants', );

=item * debug

Set to 1 to enable debugging.

=cut

has debug => (
    is  => 'ro',
    isa => Bool,
);

=item * hide

Set to 1 to disable output.

=cut

has hide => (
    is  => 'ro',
    isa => Bool,
);

has _mc => (
    is      => 'lazy',
    isa     => InstanceOf ['Mail::Chimp3'],
    builder => sub { my $self = shift; Mail::Chimp3->new( api_key => $self->api_key, debug => $self->debug ) },
);

has _ic => (
    is      => 'ro',
    isa     => InstanceOf ['Ext::OurTags'],
    default => sub { Ext::OurTags->new( { logfile => ( $Vend::Cfg->{Variable}{LOGDIR} || 'logs' ) . '/mailchimp3.log' } ) },
);

has _json => (
    is      => 'ro',
    isa     => InstanceOf ['JSON'],
    default => sub { JSON->new },
);

has _v2_method_map => (
    is      => 'ro',
    default => sub {
        {
            'campaigns/list'    => 'campaigns',
            'ecomm/order-add'   => 'add_order',
            'ecomm/order-del'   => 'delete_order',
            'ecomm/orders'      => 'orders',
            'lists/list'        => 'lists',
            'lists/member-info' => 'member',
            'lists/members'     => 'members',
            'lists/merge-vars'  => 'merge_fields',
            'lists/subscribe'   => 'upsert_member',
            'lists/unsubscribe' => 'delete_member',
        }
    },
);

has _v2_opt_map => (
    is      => 'ro',
    default => sub {
        {
            'email_address' => 'email_address',
            'email-address' => 'email_address',
            'email'         => 'email_address',
            'emails'        => 'email_address',  # if this was an array > 1, would need a batch now
            'double-optin'  => 'double_optin',
            'double_optin'  => 'double_optin',
            'id'            => 'list_id',
            'merge_vars'    => 'merge_fields',
            'order_id'      => 'order_id',
            'queue'         => 'queue',
            'store_id'      => 'store_id',
        }
    },
);

=back

=head2 "Set" Methods

=head3 $mc->queue( $method, $opt )

Enqueue the request for later processing.

=cut

sub queue ( $self, $method, $opt={} ) {
    my $qdb = $self->_ic->dbh('mailchimp_queue')
        or return $self->_ic->die('no queue table');

    $opt = $self->_massage_options($opt, $method);  # must massage here, as the uneval will convert undef to ''

    $qdb->do(
        q{INSERT INTO mailchimp_queue ( method, opt ) VALUES ( ?, ? )},
        {},
        $method, $self->_ic->uneval($opt)
    ) or return $self->_ic->die('could not insert: %s', $qdb->errstr );

$self->_ic->log("queued $method, opts were: " . $self->_ic->uneval($opt) );
    return $self->hide ? undef : 1;
}

=head3 $mc->do( $method, $opt )

Process the request against the MailChimp API.

=cut

sub do ( $self, $method, $opt={} ) {
#$self->_ic->log('opt was: %s', $self->_ic->uneval($opt, 1) );
    my $old_methods = $self->_v2_method_map || {};
#$self->debug and $self->_ic->log('method was: %s, now: %s', $method, $old_methods->{$method} || '' );
    $old_methods->{$method} and ($method, $opt) = $self->_convert_old( $old_methods->{$method}, $opt );

    $opt = $self->_massage_options($opt, $method);
$self->debug and $self->_ic->log('opt now %s', $self->_ic->uneval($opt, 1) );

    my $result = keys %$opt ? $self->_mc->$method(%$opt) : $self->_mc->$method;
    !ref $result and return $result;

    $result->{error}
        and return $self->hide
            ? $self->_ic->log( $result->{error} )
            : $self->_ic->die( '%s for: %s, content: %s', $result->{error}, $method, $self->_ic->uneval($result->{content},1) );

    !$result->{code} or $result->{code} !~ /^20/
        and return $self->_ic->die( 'failed for method "%s": %s. original opt: %s',
            $method,
            $self->_ic->uneval( $result->{content}, 'pretty' ),
            $self->_ic->uneval( $opt, 'pretty' ),
        );

    my $response
        = ref $result->{content}
        ? $self->_format_response( $result->{content}{$method} || $result->{content} )
        : 1;

$self->_ic->log('performed %s. response: %s', $method, $self->_ic->uneval($response, 'pretty') );
    return $self->hide ? undef : $response;
}

=head3 $mc->create_products( $products )

Create products in MailChimp.

You need to construct this module with the C<store_id> parameter.

You'll want to run this 2-3 times per day via an Interchange job, e.g.:
    [mailchimp create_products=1 store_id="TestStore"]

Initially, you may need to run a few times in a row to get all your
products, as IC jobs have a 30 minute timeout. (Although this can do
about 11,000 in 30 minutes...)

=cut

sub create_products ( $self, $only_new=1 ) {
    return $self->_ic->die('need store_id constructor parameter') unless $self->store_id;

    # find current products, just the 'id' field to be fast
    my $their_ids = $self->do( 'products', { fields => 'products.id', count => 999999 } ) || [];
    my %theirs = map { $_->{id} => 1 } @$their_ids;

    # see if they match what we have in _our_products
    my $update_results = [];
    my $our_prods = $self->_our_products();
    my $i = 0;
    my $count = scalar @$our_prods;
    for my $prod (sort { $a->{id} <=> $b->{id} } @$our_prods) {
$self->_ic->log( 'checking %s of %s: %s', $i++, $count, $prod->{id} );
        if ( $theirs{ $prod->{id} } ) {
            next unless ! $only_new;    # continue unless doing all
            # if already eixsts, get variant, and check if same
            my $theirs_full = $self->do( 'product', { product_id => $prod->{id}, fields => 'variants' } );
            $self->_same_structs( $prod->{variants}, $theirs_full->{variants} )
                and next;
$self->_ic->log( 'exists, but variants do not match for %s, going to update', $prod->{id} );
            # update variant -- can't update parent at this time
            # see: http://developer.mailchimp.com/documentation/mailchimp/reference/ecommerce/stores/products/
            my $update_var_ary = $prod->{variants};
            for my $var (@$update_var_ary) {
                $var->{product_id} = $prod->{id};
                $var->{variant_id} = $var->{id};
                my $res = $self->do( 'upsert_variant', $var );
                push @$update_results, $res;
            }
        }
        else {
$self->_ic->log( 'does not exist, going to add %s', $prod->{id} );
            my $res = $self->do( 'add_product', $prod );
            push @$update_results, $res;
        }
    }
    return $self->debug ? $update_results : sprintf('Updated %s products.', scalar @$update_results);
}

=head1 INTERNALS

=over

=item _format_response

Strips out the C<_links> hash keys or any other leading-underscore keys.

=cut

sub _format_response ( $self, $response ) {
    ref $response eq 'ARRAY' and map { $self->_format_response($_) } @$response;
    ref $response eq 'HASH' and do {
        return 1 if ! scalar keys %$response;
        map { m/^_/ and delete $response->{$_} } keys %$response;
        while (my ($k,$v) = each %$response) {
            ref $v and $v = $self->_format_response($v);
            $k =~ /^_/ and delete $response->{$k};
        }
    };
    return $self->_convert_json_booleans($response);
}

=item _convert_json_booleans

Make it all perly.

=cut

sub _convert_json_booleans ( $self, $data ) {
    ref $data eq 'ARRAY' and map { $self->_convert_json_booleans($_) } @$data;
    ref $data eq 'HASH' and map { $_ = $self->_convert_json_booleans($_) } values %$data;
    JSON::is_bool($data) and $data = int($data)+0;
    return $data;
}

=item _convert_old

Transition from API v2 to v3 and uses of old [mailchimp] tag.

=cut

sub _convert_old ( $self, $method, $opt ) {
    my $opt_map = $self->_v2_opt_map || {};
    my $new_opt = {};
    while (my ($k,$v) = each %$opt) {
        $opt_map->{$k} and $new_opt->{ $opt_map->{$k} } = $v;
    }

    # unstack
    for (qw/ email_address list_id /) {
        next unless $new_opt->{$_};
        ref $new_opt->{$_} eq 'ARRAY'
            and $new_opt->{$_} = $new_opt->{$_}[0];
        ref $new_opt->{$_} eq 'HASH' and do {
            my @values = values %{$new_opt->{$_}};
            $new_opt->{$_} = shift @values;
        };
    }

    # merge fields
    $new_opt->{merge_fields} and ref $new_opt->{merge_fields} and do {
        $new_opt->{ip_opt} = delete $new_opt->{merge_fields}{optin_ip};
        for ( keys %{$new_opt->{merge_fields}} ) {
            $new_opt->{merge_fields}{ uc $_ } = delete $new_opt->{merge_fields}{$_};  # must be uppercase
        }
    };

    # upsert_member
    $method eq 'upsert_member' and do {
        $new_opt->{subscriber_hash} = md5_hex( lc $new_opt->{email_address} );
        $new_opt->{status_if_new}   = delete $new_opt->{double_optin} ? 'pending' : 'subscribed';  # true means send confirm
        $new_opt->{status}          = $new_opt->{status_if_new};
    };

    # set subscriber_hash
    $method =~ /^(?:update_|delete_)?member$/ and
        $new_opt->{subscriber_hash} = md5_hex( lc delete $new_opt->{email_address} );

    return ($method, $new_opt);
}

=item _massage_options

Various massaging of options before passing along:

 - Get rid of hash values that are undef.

 - Convert any item quantities seen for MailChimp360.

 - Convert Perl true/false for desired keys for JSON.

 - Add store_id if the method needs it.

 - Convert unique_email_id to email_address for add_order.

=cut

sub _massage_options ( $self, $opt, $method='' ) {
    ref $opt eq 'ARRAY' and map { $self->_massage_options($_) } @$opt;
    return $opt unless ref $opt eq 'HASH';

    # remove undefs
    while (my ($k,$v) = each %$opt) {
        ref $v and $v = $self->_massage_options($v);
        delete $opt->{$k} unless defined $v;
    }

    # convert item quantities to be integers
    $opt->{lines} and do {
        for my $line ( @{$opt->{lines}} ) {
            $line->{quantity} and $line->{quantity} += 0;
        }
    };

    # convert booleans
    $opt->{customer}
        and defined $opt->{customer}{opt_in_status}
        and $opt->{customer}{opt_in_status} = $opt->{customer}{opt_in_status} ? \1 : \0;

    # add store_id
    my %needs_store_id = qw(
        add_product 1
        product 1
        products 1
        upsert_variant 1
    );
    $needs_store_id{$method} and $opt->{store_id} = $self->store_id;

    # convert email_id
    $method
        and $method eq 'add_order'
        and $opt
        and $opt->{customer}
        and $opt->{customer}{email_address}
        and $opt->{customer}{email_address} = $self->_find_email_from_id( $opt->{customer}{email_address}, $opt->{campaign_id} );

    return $opt;
}

sub _find_email_from_id ( $self, $email, $campaign_id ) {
    return $email unless $email !~ /@/;
    return $email unless $campaign_id;

    my $camp = $self->do( 'campaign', { campaign_id => $campaign_id, fields => 'recipients.list_id' } );
    my $list_id = ( ref $camp and $camp->{recipients} ) ? $camp->{recipients}{list_id} : '';
    return $email unless $list_id;

    my $memb = $self->do( 'members', { list_id => $list_id, unique_email_id => $email, fields => 'members.email_address' } );
    return ( ref $memb eq 'ARRAY' and ref $memb->[0] ) ? $memb->[0]->{email_address} : $email;
}

sub _get_products ($self) {
    my $sql = sprintf(
        q{
            SELECT
                sku AS id,
                %s AS title,
                %s AS price,
                %s AS vendor
            FROM %s
        },
        $self->desc_field, $self->price_field, $self->vendor_field, $self->products_table
    );
    return $self->_ic->dbh( $self->products_table )->selectall_arrayref( $sql, { Slice => {} } );
}

sub _get_variants ($self) {
    my $variants = {};
    my $dbh;
    eval { $dbh = $self->_ic->dbh( $self->variants_table ) };
    $@ and return $variants;
    my $sql = sprintf(
        q{
            SELECT
                sku AS parent,
                code AS id,
                %s AS title,
                %s AS price
            FROM %s
        },
        $self->desc_field, $self->price_field, $self->variants_table
    );
    my $ary = $dbh->selectall_arrayref( $sql, { Slice => {} } );
    for (@$ary) {
        my $parent = delete $_->{parent};
        $_->{price} += 0;
        $variants->{$parent} ||= [];
        push @{ $variants->{$parent} }, $_;
    }
    return $variants;
}

sub _our_products ($self) {
    my $prods = $self->_get_products();
    my $vars  = $self->_get_variants();

    for my $prod (@$prods) {
        $prod->{variants} = $vars->{ $prod->{id} } || [
            {
                id    => $prod->{id},
                title => $prod->{title},
                price => $prod->{price} + 0,
            }
        ];
        delete $prod->{price};
    }
    return $prods;
}

sub _same_structs ( $self, $from, $to ) {
    return $self->_ic->die('not refs') unless ref $from and ref $to;
    my $same = 1;
    if (ref $from eq 'HASH') {
        while (my ($k,$v) = each %$from) {
            if (ref $v) {
                $same = $self->_same_structs( $v, $to->{$k} );
            }
            else {
                next if $v eq $to->{$k};  # we're only checking the keys we have, not all of their other keys
$self->debug and $self->_ic->log("$v doesn't equal $to->{$k}");
                $same = 0;
            }
        }
    }
    else {
        $same = $self->_same_structs( $_, shift @$to ) for @$from;
    }
    return $same;
}

=back

=head1 UPGRADING

When upgrading from the original [mailchimp] tag that used MailChimp API
version 2, a few adjustments are required:

=head2 Ecommerce

You need to create your store with API v3 before any of the e-commerce
methods will work. Use C<add_store>.

=head2 Method changes

=over

=item * lists/member-info & emails

If using C<[mailchimp method="lists/member-info" emails=""]> with a
hashref of emails, this is no longer supported. It will use a single
email from the hash instead.

=item * campaigns/list & filters

Filters are no longer supported when listing all campaigns.

=item * ecomm/orders

It is now required to send a C<store_id> option with this method.

=item * ecomm/order-add

This has changed drastically from the older method. We now need to
ensure the products in the order are created separately first. See
C<create_products>.

=back

=head1 AUTHOR

Josh Lavin - End Point Corp. <jlavin@endpoint.com>

=cut

1;
