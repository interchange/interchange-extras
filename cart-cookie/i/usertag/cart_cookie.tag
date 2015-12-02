UserTag cart_cookie addAttr
UserTag cart_cookie Documentation <<EOD

=head1 NAME

cart-cookie -- Remember items in the cart, via a cookie

=head1 NOTES

This tag will not work properly if the "SeparateItems" config is "Yes".

This tag will not add inactive products back to the cart, but will _not_ check for inactive variants.

With a little work, this tag could be used for wishlist creation and display.

=head1 TODO
	
Check AutoModifier and/or UseModifier and consider removing those keys from the product hash, before restoring.
The [update cart] tag will refresh these things.
Watch out for colons and exclamation points in AutoModifier keys.

Ability to transfer items to another browser if user is logged in with same username as exists in database and has no local cookie.
If we overwrote their cart when they logged in, then we would erroneously dump any items they had added before logging in.

=head1 INSTALLATION

Install this file and cart_cookie.sub in i/usertags.
Install dbconf/mysql/carts.mysql, and products/carts.txt.
Install dbconf/mysql/cart_products.mysql, and products/cart_products.txt.
Install etc/jobs/twicemonthly/remove_old_carts, and set up cronjob to run 'twicemonthly' job twice a month.

Add to catalog.cfg:

	Autoload  [cart-cookie]
	CartTrigger  cart_cookie
	CartTriggerQuantity  yes

Add near the end of etc/receipt.html:

	[cart-cookie clear=1]

=head1 COPYRIGHT

Copyright (C) Josh Lavin. All rights reserved.

This usertag is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Josh Lavin

=cut
EOD
UserTag cart_cookie Routine <<EOR
sub {
	my ($opt) = @_;

	return if $CGI::values{mv_tmp_session}; 
	return if $Vend::Session->{admin};

	use vars qw/$Tag $ready_safe/;
	my ($log, $die, $warn) = $Tag->logger('cart_cookie', 'logs/cart_cookie.log');

	my $cookie_name = $opt->{cookie} || 'MV_CART_ID';
	my $name     = $opt->{name} || 'main';
	my $type     = $opt->{type} || 'cart';
	my $uid      = $Vend::Session->{username} || $Vend::Session->{id};
	my $carts    = $Vend::Session->{carts};
	my $disc_sku = $::Variable->{PROMOTION_DISC_ITEM_SKU} || 'discount';

	my $products_table = $Vend::Cfg->{ProductFiles}[0] || 'products';
	my $prod_db = dbref($products_table)
		or return $die->("table '%s' does not exist.", $products_table);

	my $carts_table = $opt->{carts_table} || 'carts';
	my $cdb = dbref($carts_table)
		or return $die->("table '%s' does not exist.", $carts_table);

	my $cart_products_table = $opt->{cart_products_table} || 'cart_products';
	my $pdb = dbref($cart_products_table)
		or return $die->("table '%s' does not exist.", $cart_products_table);

##	
##	Create unique cookie id & set
##
	my $set = sub {
		my $expire = $opt->{expire} || $::Variable->{CART_COOKIE_EXPIRY} || '12 weeks';
		my $domain = $opt->{domain} || '';   # leave default but allow opt.
		my $path = $opt->{path} || '';   # leave default but allow opt.
#$log->("do not have cookie, setting one");

		my $ip   = $CGI::remote_addr || '127.0.0.1'; 
		my $date = POSIX::strftime("%Y%m%d%H%M%S", localtime() );
		my $cookie_id = "$ip.$date." . (int(rand(1000)) + 1);

		my $md5 = $Tag->filter('md5', $cookie_id);
$log->("Generated key $md5 for $cookie_id");
		
		Vend::Util::set_cookie($cookie_name,$md5,$expire,$domain,$path);
		return;
	};

##
##  Read cart from db and set in carts
##
	my $read = sub {
		my ($cid) = @_;
		return if $carts->{$name}[0];   ## if cart already there, then return.

#$log->("no cart with name '$name', proceeding to set items from db");
		my $inactive_field = $prod_db->config('HIDE_FIELD') || '';
		my $qcid = $pdb->quote($cid);
		my $prod_ary = $pdb->query({ sql => "SELECT * FROM $cart_products_table WHERE cart = $qcid ORDER BY position", hashref => 1 });
		my $i = 0;
		for my $p (@$prod_ary) {
			next if $p->{sku} eq $disc_sku;

			my $prod_ref = $prod_db->row_hash( $p->{sku} );
			unless ($prod_ref) {
				$die->('Product with sku %s is discontinued.', $p->{sku});
				$pdb->delete_record([ $cid, $p->{sku} ]);
				next;
			}
			if ($inactive_field and $prod_ref->{$inactive_field}) {
				$die->('Product with sku %s is discontinued.', $p->{sku});
				$pdb->delete_record([ $cid, $p->{sku} ]);
				next;
			}

			my $hash = $ready_safe->reval( $p->{hash} );
			next unless ref($hash) eq 'HASH';
			for my $k (keys %$hash) {
				delete $hash->{$k} if $k =~ /^mv_(?:max_quantity|max_over|min_under|discount(_message)?|free_shipping)$/;
			}

			my $position = ($p->{position} != $i) ? $i : $p->{position};
			$carts->{$name}[ $position ] = $hash;
			$carts->{$name}[ $position ]->{code}     = $p->{sku};
			$carts->{$name}[ $position ]->{quantity} = $p->{quantity},
#$log->("item at position $position = " . uneval( $carts->{$name}[ $position ] ) );
			$i++;
		}

#$log->("read cart and set in cart:$name");
		$Tag->update('cart');   # resets mv_max_quantity, etc, and runs the update portion of this tag.
		return;
	};

##
##	Update carts table with cart info
##
	my $update = sub {
		my ($cid, $action, $sku, $qty) = @_;

		if ($action eq 'update' and $qty == 0) {
			## remove item. we shouldn't need to check for existence in db, since would have been created on item add.
			my $del = $pdb->delete_record([ $cid, $sku ]);
#$log->("deleted item with sku:$sku") if $del;
			return;
		}

		if ( $cdb->record_exists($cid) ) {
			## at least update uid here, so last_modified will be updated.
			$cdb->set_field($cid, 'uid', $uid);
#$log->("updating uid");
		}
		else {
			## add new cart.
			my %fields = (
				name    => $name,
				type    => $type,
				uid     => $uid,
				created => POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime() ),
			);
			$cdb->set_slice($cid, \%fields)
				or return $die->("Unable to update carts for id: %s", $cid);
#$log->("set new row in carts table for $cid");
		}

		## add products to cart.
		my $cart_copy = [];
		for ( @{$carts->{$name}} ) {
			push @$cart_copy, { %$_ };
		}
		my $i = 0;
		for my $it ( @$cart_copy ) {
#$log->("working on item: " . uneval(\%$it) );
			my $psku = delete $it->{code};
			my %data = (
				quantity => delete $it->{quantity},
				position => delete($it->{mv_ip}) || $i,
				hash     => uneval(\%$it),
			);
#$log->("added/updated item with sku:$psku, data is: " .uneval(\%data) );
			$pdb->set_slice([ $cid, $psku ], \%data);
			$i++;
		}

		return;
	};


##
## Do stuff.
##
	my $cid = Vend::Util::read_cookie($cookie_name);
	return $set->() if ! $cid;

#$log->("has saved cookie: $cid");
	if ($opt->{update}) {
		$update->(
			$cid,
			$opt->{action},
			$opt->{sku},
			$opt->{qty},
			);
	}
	elsif ($opt->{clear}) {
		$cdb->delete_record($cid);
		my $qcid = $pdb->quote($cid);
		$pdb->query("DELETE FROM $cart_products_table WHERE cart = $qcid");   # also delete from pdb.
		Vend::Util::set_cookie($cookie_name,'', '', '','');
#$log->("cleared db and cookie with cid: $cid");
		return;
	}
	else {
		$read->($cid);
	}

	return;
}
EOR
