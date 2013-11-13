UserTag  mailchimp360  addAttr
UserTag  mailchimp360  Routine <<EOR
sub {
	my ($opt) = @_;

	use vars qw/$Tag/;

	my $cid_cookie_name = 'MV_MAILCHIMP_CAMPAIGN_ID';
	my $eid_cookie_name = 'MV_MAILCHIMP_EMAIL_ID';

##	
##	SUB: Create cookie
##
	my $set = sub {
		my ($cookie_name, $cookie_value) = @_;
		my $expire = $opt->{expire} || '30 days';
		my $domain = $opt->{domain} || ''; #leave default but allow opt.
		my $path = $opt->{path} || ''; #leave default but allow opt.

		Vend::Util::set_cookie($cookie_name,$cookie_value,$expire,$domain,$path);
	};

##
##  Look for MailChimp params or cookies, otherwise return
##
	if( $CGI::values{mc_cid} && $CGI::values{mc_eid} ) {
#::logDebug("mc360: found mc_cid and mc_eid");
		my $cid = $Tag->filter('encode_entities', $CGI::values{mc_cid});
		my $eid = $Tag->filter('encode_entities', $CGI::values{mc_eid});
		$set->($cid_cookie_name, $cid);
		$set->($eid_cookie_name, $eid);
		return;
	}
	elsif($opt->{order}) {
		# move on
	}
	else {
		return;
	}

##
##  Record Order
##
	if($opt->{order}) {

		my $cid_cookie = Vend::Util::read_cookie($cid_cookie_name);
		my $eid_cookie = Vend::Util::read_cookie($eid_cookie_name);
		return unless $cid_cookie && $eid_cookie;
#::logDebug("mc360: has cookies, cid=$cid_cookie, eid=$eid_cookie");

		my $cart_name = $opt->{cart_name} || 'main';
		my $carts = $Vend::Session->{carts};
		my @items;  # will be array of hashes

		# product_id and category_id might have to be integers

		for(@{$carts->{$cart_name}}) {
			my $code = $_->{mv_sku} || $_->{code};
			my $cat_name = Vend::Interpolate::product_category($code, $_->{mv_ib});
			my $cat_id  = unpack("N", pack("B32",$cat_name));   # convert to binary, then decimal
			my $sku = $Tag->filter('30', $_->{code});
			my $prod_id = unpack("N", pack("B32",$sku));
			push @items, {
				line_num      => $_->{mv_ip},
				product_id    => $prod_id,
				sku           => $sku,
				product_name  => Vend::Interpolate::product_description($_->{code}, $_->{mv_ib}),
				category_id   => $cat_id,
				category_name => $cat_name,
				qty           => $_->{quantity},
				cost          => Vend::Interpolate::product_price($_->{code}, 1, $_->{mv_ib}),
			};
#::logDebug("mc360: item added, code=$sku, product_id=$prod_id");
		}
#::logDebug("mc360: items=" . uneval(\@items));

		my %order = (
			id          => $::Values->{mv_order_number} || POSIX::strftime('%Y%m%d%H%M%S', localtime()),
			email_id    => $eid_cookie,
			total       => Vend::Interpolate::total_cost(),
			shipping    => $Tag->shipping({ noformat => 1 }),
			tax         => Vend::Interpolate::salestax(),
			store_id    => $Tag->filter('alphanumeric 20', $::Variable->{COMPANY}),
			store_name  => $::Variable->{SERVER_NAME},
			campaign_id => $cid_cookie,
			items       => \@items,
		);
#::logDebug("mc360: order=" . uneval(\%order));
		my $status = $Tag->mailchimp({ method => 'ecommOrderAdd', order => \%order, hide => 1, });
#::logDebug("mc360 status: " . $status);

	}

	return;
}
EOR

Usertag  mailchimp360  Documentation <<EOD

=head1 NAME

mailchimp360 -- sends e-commerce orders back to MailChimp

=head1 DESCRIPTION

Implements the MailChimp 360 plugin for Interchange. 

Options:

=over 4

=item order

Set to 1 if you need to record an order. This is usually done near the bottom of C<CATROOT/etc/receipt.html>, with this:

	[mailchimp360 order=1]

=back

Usage:

=over 4

Add this to C<CATROOT/catalog.cfg>:

	Autoload [mailchimp360]

=back

Testing:

=over 4

Send a test campaign to yourself with the "Ecommerce 360" tags (under Advanced Tracking options). Click a link, and submit an order. Visit this URL to see the orders:

	http://us1.api.mailchimp.com/1.3/?method=ecommOrders&apikey=[YOUR_API_KEY_HERE]

Additionally, you can uncomment the logDebug lines, and watch the debug log when placing an order. As a last resort, make sure you are getting the special MailChimp cookies assigned by Interchange.

=back

=head1 PREREQUISITES

mailchimp.tag

=head1 BUGS

The usual number.

=head1 COPYRIGHT

Copyright (C) 2012 Josh Lavin. All rights reserved.

This usertag is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Josh Lavin

EOD
