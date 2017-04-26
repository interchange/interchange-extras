Message  Including promotion.tag
UserTag promotion Order code
UserTag promotion addAttr
UserTag promotion Documentation <<EOD
=head1 NAME

promotion - Usertag to implement custom discounts

=head1 SYNOPSIS

    [promotion
        code=PROMO_CODE
        table=promotion_table
        test-only=1
        clear=1
    ]

=head1 DESCRIPTION

The [promotion] tag manipulates Interchange discounts specified in a
table, C<promotion> by default. 

=head2 Options

The required option is the code of the promotion, which specifies
the entry in the promotion table to use.

Some options are not normally used, but can be used to set the name of
the promotion table and to specify C<test-only>.

=over 4

=item code

The record identifier for the promotion. Required.

=item table

The name of the table to use for promotions. Default C<promotion>.

=item test_only

Just tests to see if the user qualifies for the promotion, does not
operate on the cart or the global discounts.

=item clear

Pass with codes and 'clear=1' to remove them and their related discounts, etc.

=head2 Promotion table

The promotion table has the following columns:

  code              Unique key specifying promotion
  timed             Whether promotion has a start and end date
  inactive          Inactive -- flag to turn off a promotion.
  start_date        Start date when timed.
  finish_date       End date when timed.
  discount_type     Type -- ENTIRE_ORDER, ALL_ITEMS, GROUP, or SKU
  discount          The percentage off
  discount_code     Custom discount code if not percentage off
  qualify_group     The pricing group which qualifies for a GROUP promotion
  qualify_number    The number needed to purchase to qualify
  qualify_subtotal  The order subtotal needed to qualify
  qualify_code      Custom code that determines qualification
  free_item         A free item to be added when qualified
  free_message      A note to attach to the free item when qualified
  note              A note to attach to the discount when qualified
  disqualify_note   The message to send (to the error hash) when not qualified

Not all fiields should be set for every promotion.

=head2 Qualification Priority 

1. If C<qualify_code> is set, that code will be run to determine the discount
qualification.

2. If no preceding option is set, and C<qualify_group> is set, a temporary
cart containing only items from the C<qualify_group> price_group is created.
Further tests and discounts only apply to that group.

3. If no preceding option is set, and C<qualify_subtotal> is set, the
promotion will qualify only when the user's discounted subtotal
is greater than this number.

4. If no preceding option is set, the promotion is qualified.

=head2 Operation

To use, call the tag with a promotion code. 

=head2 Operation Cookbook

This record sets a promotion C<123> for price group C<promo1> while
adding the item C<os28057a> free.

	code:123
	timed:1
	inactive:
	start_date:20031015
	finish_date:20031220
	discount_type:GROUP
	discount:10%
	discount_code:
	qualify_group:promo1
	qualify_number:3
	qualify_subtotal:
	qualify_code:
	free_item:os28057a
	free_message:
	note:10 percent off!

It operates from 15-Oct-2003 to 20-Dec-2003. If three items (number in
qualify_number) are purchased from that group, a 10% discount is applied
to items in that group. If qualified, a C<os28057a> is added to the
cart, and it is given a price of zero for quantity one. (Additional
items added via cart manipulation will cost the regular price for
C<os28057a>.)

=cut

=head2 Promotion table fields

 Field	Type	Null	Key	Default	Extra
 code	varchar(64)	NO			
 timed	varchar(3)	YES		NULL	
 inactive	varchar(3)	YES		NULL	
 start_date	varchar(24)	YES		NULL	
 finish_date	varchar(24)	YES		NULL	
 discount_type	varchar(64)	YES		NULL	
 discount	varchar(255)	YES		NULL	
 discount_code	varchar(255)	YES		NULL	
 qualify_group	varchar(255)	YES		NULL	
 qualify_number	varchar(255)	YES		NULL	
 qualify_subtotal	varchar(255)	YES		NULL	
 qualify_sku	varchar(64)	YES		NULL	
 qualify_code	varchar(255)	YES		NULL	
 free_item	varchar(255)	YES		NULL	
 free_message	varchar(255)	YES		NULL	
 note	text	YES		NULL	
 home_page	varchar(255)	YES		NULL	
 disqualify_note	varchar(255)	YES		NULL	
 free_shipping	varchar(255)	YES		NULL	
 recur_interval	varchar(32)	YES		NULL	
 auth_by	varchar(255)	YES		NULL	
 create_date	varchar(255)	YES		NULL	
 description	varchar(255)	YES		NULL	
 apply_multiple	varchar(255)	YES		NULL	

=cut

EOD

UserTag promotion Routine <<EOR
sub {
	my ($code, $opt) = @_;
	use vars qw/$Tag $Items $Carts $ready_safe/;
	my ($log, $nevairbe_die, $nevairbe_warn) = $Tag->logger('promotion', 'logs/promotion.log');

	my $orig_code = $code;
	$code =~ s/[^-\w]+//g;
	$code = uc($code);

	## Return true if no promotion asked for
	return 1 if ! $code;

#$log->("in promotion tag");
	my $d = $Vend::Session->{discount} ||= {};

	my $tab = $opt->{table}
			|| $::Variable->{MV_PROMOTION_TABLE}
			|| 'promotion';
	my $die = sub {
		my $msg = errmsg(@_);
		$Tag->error({ name => 'promotion', set => $msg });
		Log( "died: $msg", { file => 'promotion' });
		delete $::Values->{promo_code};
		return undef;
	};
	my $error = sub {
		my $msg = errmsg(@_);
		$Tag->error({ name => 'promotion', set => $msg });
		delete $::Values->{promo_code};
		return undef;
	};
	my $db = ::database_exists_ref($tab)
		or return $die->("Promotion table '%s' does not exist.", $tab);
	my $record = $db->row_hash($code)
		or return $error->("Invalid promotion code '%s'", $orig_code);

	my $incremented_finish = 0;
	## Check for timed validity
  CHECKTIMED: {
	if($record->{timed}) {
		my $now = POSIX::strftime('%Y%m%d%H%M%S', localtime());
		if($record->{start_date} gt $now) {
#$log->("timed, not valid yet");
			return $error->(
					"Promotion code '%s' not valid yet, starts %s",
					$code,
					$Tag->convert_date({fmt => '%c', body => $record->{start_date}}),
					);
		}
		elsif($record->{finish_date} lt $now) {
#$log->("timed, expired already");
			if($record->{recur_interval} and $incremented_finish++ < 20) {
				SETRECUR: {
					my $adder = Vend::Config::time_to_seconds($record->{recur_interval});
					if($adder <= 0) {
						::logError("bad recurrence interval on promotion %s: %s",
							$code,
							$record->{recur_interval},
							);
						last SETRECUR;
					}
					my $adder_days = $adder / 86400;
					my $start_fmt = '%Y%m%d';
					my $finish_fmt = '%Y%m%d';
					if(length $record->{start_date} > 8) {
						$start_fmt = '%Y%m%d%H%M';
					}
					if(length $record->{finish_date} > 8) {
						$finish_fmt = '%Y%m%d%H%M';
					}
					my $finish = $Tag->convert_date({ 
											fmt => $finish_fmt,
											adjust => $adder_days,
											body => $record->{finish_date},
											});
					my $start = $Tag->convert_date({ 
											fmt => $start_fmt,
											adjust => $adder_days,
											body => $record->{start_date},
										});
					$db->set_slice($code,
									{ 
										start_date =>  $start,
										finish_date =>  $finish,
									},
								);
					$record->{start_date} = $start;
					$record->{finish_date} = $finish;
					redo CHECKTIMED;
				}
			}
			return $error->(
					"Promotion code '%s' is expired, ended %s",
					$code,
					$Tag->convert_date({fmt => '%c', body => $record->{finish_date}}),
					) if $record->{disqualify_note} =~ /\S/;
			return;
		}
	}
  }
	## Check for inactive
	if($record->{inactive}) {
		return $error->("Promotion code '%s' has been discontinued.", $code);
	}

	## Check if already used
	if($record->{once_per_customer} && ! $opt->{clear}) {
		if($::Values->{email}) {
			my $tdb = ::database_exists_ref('transactions')
				or return $die->("transactions table does not exist.");
			my $qemail = $tdb->quote($::Values->{email});
			my $qcode  = $tdb->quote($code);
			my $tq = "SELECT 'used' FROM transactions WHERE email = $qemail AND promo_code = $qcode";
			my ($used_ary) = $tdb->query($tq);
			return $error->("You have already used promotion code '%s'.", $code) if scalar(@$used_ary);
		}
	}

	if($record->{new_customers_only} && ! $opt->{clear}) {
		if($::Values->{email}) {
			my $udb = ::database_exists_ref('userdb')
				or return $die->("userdb table does not exist.");
			my $qemail = $udb->quote($::Values->{email});
			my $uq = "SELECT 'existing' FROM userdb u, transactions t WHERE u.email = $qemail and t.username=u.username";
			my ($existing_ary) = $udb->query($uq);
			return $error->('For new customers only.') if scalar(@$existing_ary);
		}
	}

	## A promotion that is external in nature, just using the promotion table
	if(lc($record->{discount_type}) eq 'external') {
		return; 
	}

#$log->("passed timed, passed inactive, discount_type=$record->{discount_type}");
	my $qualified;

	my @qual_index;

	## Check qualification
	if($record->{qualify_code}) {
		my $result = $ready_safe->reval($record->{qualify_code});
		if($result) { $qualified = 1 }
	}
	elsif($record->{qualify_group}) {
		my $tab_field = $::Variable->{PROMOTION_GROUP_FIELD} || 'pricing::price_group';
		my ($tab, $field) = split /:+/, $tab_field;
		if(! $field) {
			$field = $tab;
			$tab = '';
		}
		my $tmp_cart = $Carts->{tmp_cart} = [];
		my $i = -1;
		for my $item (@$Items) {
			$i++;
			$item->{price_group} ||= tag_data($tab || $item->{mv_ib}, $field, $item->{mv_sku} || $item->{code});
#$log->("tmp_cart price_group=$item->{price_group} comp=$record->{qualify_group}");
			next unless $item->{price_group} eq $record->{qualify_group};
			push @qual_index, $i;
			push @$tmp_cart, { %$item };
		}

		my $num;
		my $comp;
		if($comp = $record->{qualify_lines}) {
			$num = scalar(@$tmp_cart);
			$qualified = 1 if  $num >= $comp;
#$log->("qualify_lines num=$num comp=$comp");
		}
		elsif($comp = $record->{qualify_number}) {
			$num = tag_nitems('tmp_cart');
			$qualified = 1 if  $num >= $comp;
#$log->("qualify_number num=$num comp=$comp cart=" . ::uneval($tmp_cart));
		}
		elsif($comp = $record->{qualify_subtotal}) {
			$num = subtotal('tmp_cart');
			$qualified = 1 if  $num >= $comp;
#$log->("qualify_subtotal num=$num comp=$comp");
		}

#$log->("qualify_group num=$num comp=$comp qual=$qualified");

	}
	elsif($record->{qualify_subtotal}) {
		my $subtotal = subtotal(undef, undef, 1);
		if($subtotal >= $record->{qualify_subtotal}) {
			$qualified = 1;
#$log->("qualify_subtotal subtotal=$subtotal qualify_subtotal=$record->{qualify_subtotal} qual=$qualified");
		}
	}
	elsif($record->{qualify_number}) {
		my $num = tag_nitems();
		my $less;
		for my $item (@$Items) {
			$less += $item->{quantity} if $item->{is_free};
		}
		$num -= $less;
		if($num >= $record->{qualify_number}) {
			$qualified = 1;
		}
	}
	elsif($record->{qualify_variant}) {
		my $var_cart = $Carts->{var_cart} = [];
		my $i = -1;
		for my $item (@$Items) {
			$i++;
#$log->("var_cart parent_sku=$item->{mv_sku} comp=$record->{qualify_variant}");
			next unless $item->{mv_sku} eq $record->{qualify_variant};
			push @qual_index, $i;
			push @$var_cart, { %$item };
		}
		my $num = scalar(@$var_cart);
		$qualified = 1 if $num;
#$log->("qualify_variant num=$num qual=$qualified");
	}
	elsif($record->{qualify_sku}) {
		$record->{discount_type} ||= 'SKU';
		my $qty;
		for(@$Items) {
			$_->{code} = uc $_->{code};
			$_->{sku}  = uc $_->{sku};
			next unless $_->{code} eq $record->{qualify_sku} || $_->{sku} eq $record->{qualify_sku};
			next if $_->{is_free};
			$qty += $_->{quantity};
			last;
		}
		if($qty) {
			if($record->{qualify_sku_number}) {
				$qualified = 1 if $qty >= $record->{qualify_sku_number};
			}
			else {
				$qualified = 1;
			}
#$log->("qualify_sku qty=$qty qual=$qualified");
		}
	}

	if($record->{discount_type} eq 'specials') {
         $qualified = 1;
    }

	return $qualified if $opt->{test_only};

	my @free;
	if($record->{free_item}) {
		@free = grep /\S/, split /[\s,\0]/, $record->{free_item};
#$log->("promotion is for free_item: " . join ',',@free);
	}

	if($record->{discount_type} eq 'QB_DOLLOFF') {
#$log->("promotion is for quickbooks dollars-off");
		my $sku  = $::Variable->{PROMOTION_DISC_ITEM_SKU} || 'discount';
		my $desc = $::Variable->{PROMOTION_DISC_ITEM_DESC} || 'Promotional discount';
		my $found;
		my $i = -1;
		for my $item (@$Items) {
			$i++;
			next unless $item->{code} eq $sku;
			push @qual_index, $i;
			$found = 1;
		}
		if(! $found) {
			push @$Items, { code => $sku, quantity => 1, description => $desc, mv_price => $record->{discount}, mv_nontaxable => 1, };
			my $i = @$Items - 1;
			push @qual_index, $i;
		}
	}

	if($opt->{clear}) {
		$qualified = '';
		delete $Vend::Session->{warnings};
		delete $Vend::Session->{errors};
	}

## ineligible items
	if($record->{discount_type} =~ /^(QUALIFYING_ITEMS|QB_DOLLOFF)$/ and my $exc = $record->{exclude_all_items}) {
		my @excs = split /,\s*/, $exc;
		for(@excs) {
			my ($col, $val) = split /:/;
			next unless $val;
			for(grep {$_->{$col} eq $val} @$Items) {
				$_->{discount_ineligible} = 1;
			}
		}
	}

	my $ineligible;
#	for(@$Items) {
#		$ineligible++ if $_->{discount_ineligible};
#	}

	if(
		$ineligible and (
			$record->{discount_type} eq 'ALL_ITEMS' or
			$record->{discount_type} eq 'ENTIRE_ORDER' or
			$record->{discount_type} eq 'QB_DOLLOFF'
		)
	) {
		$error->("Discounts cannot be taken during a shopping session when items are ineligible for discounts");
		$qualified = '';
	}
##

	if(! $qualified) {
		if($record->{discount_type} eq 'SKU') {
			delete $d->{$record->{qualify_sku}};
		}
		elsif($record->{discount_type} eq 'VARIANT') {
			for( grep {$_ =~ /^$record->{qualify_variant}/} keys %$d ) {
				delete $d->{$_};
			}
		}
		elsif($record->{discount_type} eq 'ALL_ITEMS') {
			delete $d->{ALL_ITEMS};
		}
		elsif($record->{discount_type} eq 'QUALIFYING_ITEMS') {
			for(@$Items) {
				delete $_->{mv_discount};
				delete $_->{mv_discount_message};
				delete $_->{discount_ineligible};
			}
		}

		for(@qual_index) {
			delete $Items->[$_]->{mv_discount};
			delete $Items->[$_]->{mv_discount_message};
			delete $Items->[$_]->{discount_ineligible};
			if($record->{discount_type} eq 'QB_DOLLOFF') { delete $Items->[$_] }
		}

		## also need to remove all_free_shipping...
		for(@$Items) {
			delete $_->{mv_free_shipping};
		}

		if(@free) {
			my $need_scrub;
			for my $scrub (@free) {
				for(@$Items) {
					next unless $_->{code} eq $scrub;
					next unless $_->{is_free};
					$_->{quantity} = 0;
					$need_scrub = 1;
				}
			}
			$Tag->update('cart') if $need_scrub;
		}

		delete $::Values->{promo_code};
		delete $::Scratch->{promo_code};
		return 1 if $opt->{clear};
		return $error->("Sorry, your order does not currently qualify for the special associated with this promotion code: '%s'. %s", $code, $record->{disqualify_note});
	}

	my $generate_code = sub {
		my $thing = shift;
		$thing =~ s/^\s+//;
		$thing =~ s/\s+$//;
		if($thing =~ /^-?(\d+(?:\.\d+)?)\s*\%/) {
			my $number = $1;
			if($number > 99) {
				return $die->("Refuse to give discount > %s%%", $number);
			}
			$number /= 100;
			my $val = 1 - $number;
			return "\$Tag->filter({ op => \'round\'}, \$s * $val)";
		}
		elsif($thing =~ /^-?(\d+(?:\.\d+)?)/) {
			my $number = $1;
			if($record->{discount_type} eq 'ENTIRE_ORDER') {
				return <<EOF;
if(\$s <= $number) {
	\$Tag->error({ name => 'promotion', set => 'promotion cannot set total price to zero or negative!'} );
}
return \$s - $number
EOF
			}
			else {
				return <<EOF;
if(\$s <= $number) {
	\$Tag->error({ name => 'promotion', set => 'promotion cannot set total price to zero or negative!'} );
}
return \$s - (\$q * $number)
EOF
			}
		}
	};

#$log->("valid promotion, discount_type=$record->{discount_type}");

	my $no_multiple;
	my $no_multiple_item;

	for(@$Items) {
		$no_multiple_item = 1 if $_->{no_multiple_discount};
	}

	if($record->{discount_type} eq 'ALL_ITEMS') {
		$no_multiple = 1 if $no_multiple_item;
	}
	elsif ($record->{discount_type} eq 'ENTIRE_ORDER') {
		$no_multiple = 1 if $no_multiple_item;
	}
	elsif(not $record->{apply_multiple} and $d->{ENTIRE_ORDER} || $d->{ALL_ITEMS}) {
		$no_multiple = 1;
	}

	if(($::Scratch->{promo_no_multiple} || not $record->{apply_multiple}) and $::Scratch->{promo_code} and ( uc $::Scratch->{promo_code} ne $code )) {
#$log->("no multiple discounts allowed... qual_index=" . join ',',@qual_index);
		$no_multiple = 1;
		$::Values->{promo_code} = $::Scratch->{promo_code};
		for(@qual_index) {
			delete $Items->[$_]->{mv_discount};
			delete $Items->[$_]->{mv_discount_message};
			if($record->{discount_type} eq 'QB_DOLLOFF') { delete $Items->[$_] }
		}
	}
	$::Scratch->{promo_no_multiple} ||= ! $record->{apply_multiple};
#$log->("TEST: scratch-promo_no_multiple:$::$Scratch->{promo_no_multiple}, rec->applymultiple=$record->{apply_multiple}, no_multiple_item=$no_multiple_item, no_multiple=$no_multiple, scratch=$::Scratch->{promo_code}, code=$code, value=$::Values->{promo_code}");

	if($no_multiple) {
		return $error->("This discount cannot be used in combination with other discounts.");
	}

	## Now a valid promotion
	## changed below b/c there may not always be a discount (i.e. free item only)
	my $disc;
	if($record->{discount} || $record->{discount_code}) {
		$disc = $record->{discount_code} ? $record->{discount_code} : $generate_code->($record->{discount})
			or return undef;
	}

	my $all_free_shipping;

#$log->("Embarking on discount with discount_type=$record->{discount_type}, disc=$disc");
	if($record->{discount_type} eq 'SKU') {
		if($opt->{delete}) {
			delete $d->{$record->{qualify_sku}};
		}
		else {
			$d->{$record->{qualify_sku}} = $disc;
			for(@$Items) {
				next unless $_->{code} eq $record->{qualify_sku} || $_->{sku} eq $record->{qualify_sku};
				$_->{mv_free_shipping} = 1 if $record->{free_shipping};
				$_->{no_multiple_discount} = ! $record->{apply_multiple};
			}
		}
		$Tag->warnings($record->{note}) if $record->{note};
	}
	elsif($record->{discount_type} eq 'VARIANT') {
		if($opt->{delete}) {
			for(@qual_index) {
				delete $d->{$Items->[$_]->{code}};
			}
		}
		else {
			for(@qual_index) {
				$d->{$Items->[$_]->{code}} = $disc;
				$Items->[$_]->{mv_free_shipping} = 1 if $record->{free_shipping};
				$Items->[$_]->{no_multiple_discount} = ! $record->{apply_multiple};
			}
		}
		$Tag->warnings($record->{note}) if $record->{note};
	}
	elsif($record->{discount_type} eq 'ALL_ITEMS') {
		$d->{ALL_ITEMS} = $disc;
		$all_free_shipping = 1 if $record->{free_shipping};
		$Tag->warnings($record->{note}) if $record->{note};
	}
	elsif ($record->{discount_type} eq 'ENTIRE_ORDER') {
		$d->{ENTIRE_ORDER} = $disc;
		$all_free_shipping = 1 if $record->{free_shipping};
		$Tag->warnings($record->{note}) if $record->{note};
	}
	elsif ($record->{discount_type} eq 'QUALIFYING_ITEMS') {
		my $warned;
		for my $item (@$Items) {
			next if $item->{discount_ineligible};
			$item->{mv_discount} = $disc;
			$item->{mv_discount_message} = $record->{note};
			$item->{mv_free_shipping} = 1 if $record->{free_shipping};
			$item->{no_multiple_discount} = ! $record->{apply_multiple};
			$Tag->warnings($record->{note}) 
				if $record->{note} && ! $warned++;
		}
	}
	elsif ($record->{discount_type} =~ /^(GROUP|VARIANT|QB_DOLLOFF)$/) {
		my $warned;
		for(@qual_index) {
			next if $Items->[$_]->{discount_ineligible};
			$Items->[$_]->{mv_discount} = $disc;
			$Items->[$_]->{mv_discount_message} = $record->{note};
			$Items->[$_]->{mv_free_shipping} = 1 if $record->{free_shipping};
			$Items->[$_]->{no_multiple_discount} = ! $record->{apply_multiple};
			$Tag->warnings($record->{note}) 
				if $record->{note} && ! $warned++;
		}
	}
	elsif ($record->{discount_type} eq 'MESSAGE_ONLY') {
		my $warned;
		if(@qual_index) {
			for(@qual_index) {
				$Items->[$_]->{mv_discount} = '';
				$Items->[$_]->{mv_discount_message} = $record->{note};
				$Items->[$_]->{mv_free_shipping} = 1 if $record->{free_shipping};
				$Items->[$_]->{no_multiple_discount} = ! $record->{apply_multiple};
				$Tag->warnings($record->{note}) 
					if $record->{note} && ! $warned++;
			}
		}
		else {  ## must be free shipping (no other discounts) for entire order
			$all_free_shipping = 1 if $record->{free_shipping};
			$Tag->warnings($record->{note}) if $record->{note};
		}
	}
	else {
		my $cart = $Vend::Session->{carts}{ $opt->{cart} || 'main' };
		my $found;
		for(@$cart) {
			next unless $_->{code} eq $record->{code};			
			$_->{mv_free_shipping} = 1 if $record->{free_shipping};
			$_->{no_multiple_discount} = ! $record->{apply_multiple};
			$found = 1;
		}
		if(! $found and ! $opt->{always}) {
			$opt->{invalid_item_message} ||= <<EOF;
Valid promotion '%s' does not apply to any items in your cart, it
applies to SKU %s. Please check your purchase.
EOF
			return $die->(
						$opt->{invalid_item_message},
						$code,
						$record->{discount_type},
					);
		}
		$Tag->warnings($record->{note}) if $record->{note};
		$d->{$record->{code}} = $disc;
#$log->("set sku $record->{code} discount to: $d->{$record->{code}}");
	}

	for my $add (@free) {
#$log->("ready to add free item: $add");
		my $found;
		my $disc = 'my $p = $s/$q; return $p * ($q - 1)';
		for(@$Items) {
			next unless $_->{code} eq $add;
			next unless $_->{is_free};
			$found = 1;
			$_->{mv_discount} = $disc;
			$_->{mv_discount_message} = $record->{free_message};
			$_->{mv_free_shipping} = 1 if $record->{free_shipping};
		}
		if(! $found) {
			my $ib = Vend::Data::product_code_exists_tag($add);
			if(! $ib) {
				::logError("Free item %s not found, cannot add for promotion", $add);
				next;
			}
			my %it = (
				code => $add,
				quantity => 1,
				mv_ib => $ib,
				mv_discount => $disc,
				mv_discount_message => $record->{free_message},
				is_free => 1,
			);
			if($ib eq 'variants') {
				$it{mv_sku} = tag_data($ib, 'sku', $add);
				$it{option_type} = tag_data('products', 'option_type', $it{mv_sku});
			}
			$it{mv_free_shipping} = 1 if $record->{free_shipping};
			push @$Items, \%it;
		}
	}

	if($all_free_shipping) {
		my $cart = $Vend::Session->{carts}{ $opt->{cart} || 'main' };
		for(@$cart) {
			$_->{mv_free_shipping} = 1;
			$_->{no_multiple_discount} = ! $record->{apply_multiple};
		}
	}

	if($::Values->{country} ne 'US') {
		for(@qual_index) {
			delete $Items->[$_]->{mv_free_shipping};
		}
		if($all_free_shipping) {
			my $cart = $Vend::Session->{carts}{ $opt->{cart} || 'main' };
			for(@$cart) {
				delete $_->{mv_free_shipping};
				delete $Vend::Session->{warnings} if $record->{discount_type} eq 'MESSAGE_ONLY';
			}
		}
		$Tag->warnings('Sorry, free shipping not available outside US.');
	}

	$::Scratch->{promo_code} = join(' ', $::Scratch->{promo_code}, $code) if $code ne $::Scratch->{promo_code};
	$::Scratch->{promo_code} =~ s/^\s+//;

	return 1;
}
EOR
