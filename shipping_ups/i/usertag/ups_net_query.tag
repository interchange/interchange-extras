# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: ups_net_query.tag,v 1.00 2011-05-13 23:40:57 ghanson Exp $

UserTag  ups-net-query  Order    mode origin zip weight country
UserTag  ups-net-query  addAttr
UserTag  ups-net-query  Version  $Revision: 1.12 $
UserTag  ups-net-query  Routine  <<EOR
sub {
 	my ($mode, $origin, $zip, $weight, $country, $opt) = @_;
	$opt ||= {};

#::logDebug("in ups_net_query opts:" . uneval($opt));

	use Net::UPS;
	use Net::UPS::Address;
	use Net::UPS::Rate;
	use Net::UPS::Package;
	use Net::UPS::ErrorHandler;

##UPS Account

	my $accesskey = $::Variable->{UPS_ALN} || $opt->{ups_aln};  # developer/access key
	my $userid = $::Variable->{UPS_UID} || $opt->{ups_uid};
	my $pw = $::Variable->{UPS_PW} || $opt->{ups_pw};

	my $nego_opt = $opt->{negotiated_rates};
	my $nego_var = $::Variable->{UPS_NEGOTIATED_RATES};
	my $nego = defined $nego_opt ? $nego_opt : $nego_var;
	my $negotiated_rates = defined $nego ? $nego : 1;
#::logDebug("nego = $negotiated_rates. nego_var=$nego_var, nego_opt=$nego_opt");
	my $pickup_type = $::Variable->{UPS_PICKUP_TYPE} || $opt->{pickup_type};
	my $ups_account_number = $::Variable->{UPS_ACCT_NUM} || $opt->{ups_account_number};
	my $customer_classification = $::Variable->{UPS_CUST_CLASS} || $opt->{customer_classification};

	my %args;

	if ($pickup_type){
		$args{pickup_type} = $pickup_type;
	}
	if ($ups_account_number){
		$args{ups_account_number} = $ups_account_number;
	}
	if ($customer_classification){
		$args{customer_classification} = $customer_classification;
	}
	if ($negotiated_rates){
		$args{negotiated_rates} = $negotiated_rates;
	}

##Account Status default is test

	if ($opt->{live}){
		Net::UPS->live(1);
	}


##Package Params

	my $pkg_type	= $opt->{pkg_type} || 'PACKAGE';
	my $length	= $opt->{length} || 1;
	my $width	= $opt->{width} || 1;
	my $height	= $opt->{height} || 1;

	my @sides = sort ($length, $width, $height);
    my $len = pop(@sides);  # Get longest side
    my $girth = ((2 * $sides[0]) + (2 * $sides[1]));
    my $size = $len + $girth;

	## too small weights need to be increased...
	if ($weight > 0 && $weight < 0.1) {
		$weight = 0.1;
	}

    if (($len > 108) || ($weight > 150) || ($size > 165)) {
		my $pmsg = "That package size/weight is not supported for UPS mode $mode";  
		$Vend::Session->{ship_message} .= $pmsg;
		return 0;
    }

##From Address
##Entire origin address should be used for accurate quotes and for some
##international queries is required

	$origin	= $::Variable->{UPS_ORIGIN} || $opt->{o_zip} ||$::Variable->{UPS_O_POSTCODE_FIELD} || '84663';

	my $o_city	= $opt->{o_city} || $::Variable->{UPS_O_CITY} || 'Springville';
	my $o_state	= $opt->{o_state} || $::Variable->{UPS_O_STATE} || 'UT';
	my $o_country = $opt->{o_country} || $::Variable->{UPS_O_COUNTRY} || 'US';
	my $o_zip	=  $opt->{o_zip} || $::Variable->{UPS_O_POSTCODE} || '84663';
					

##To Address

	$country	= $::Values->{$::Variable->{UPS_COUNTRY_FIELD}}
					if ! $country;
	$zip		= $::Values->{$::Variable->{UPS_POSTCODE_FIELD}}
					if ! $zip;

	my $city	= $opt->{city} || $::Values->{city};
	my $state	= $opt->{state} || $::Values->{state};
	my $is_res	= $opt->{is_res} || $::Values->{mv_ship_residential};
#::logDebug("is_res=$is_res");

##Service modes
##Add as necessary - right side must exist in Net::UPS

	my %service = (
      '1DA' => 'NEXT_DAY_AIR',
      'upsr' => 'NEXT_DAY_AIR',
      '2DA' => '2ND_DAY_AIR',
      'upsb' => '2ND_DAY_AIR',
      'GND' => 'GROUND',
      'upsg' => 'GROUND',
      'XPR' => 'WORLDWIDE_EXPRESS',
      'XPD' => 'WORLDWIDE_EXPEDITED',
      'STD' => 'STANDARD',
      'cang' => 'STANDARD',
      '3DS' => '3_DAY_SELECT',
      'ups3' => '3_DAY_SELECT',
      '1DP' => 'NEXT_DAY_AIR_SAVER',
      'upsrs' => 'NEXT_DAY_AIR_SAVER',
      '1DM' => 'NEXT_DAY_AIR_EARLY_AM',
      'XDM' => 'WORLDWIDE_EXPRESS_PLUS',
      '2DM' => '2ND_DAY_AIR_AM',
      'upsbam' => '2ND_DAY_AIR_AM',
      'SVR' => 'UPS_SAVER',
	);

##Legacy aggregate

	my $modulo = $opt->{aggregate};

	if($modulo and $modulo < 10) {
		$modulo = $::Variable->{UPS_QUERY_MODULO} || 150;
	}
	elsif(! $modulo) {
		$modulo = 9999999;
	}

	$country = uc $country;

    my %exception;

	$exception{UK} = 'GB';

	if(! $::Variable->{UPS_COUNTRY_REMAP} ) {
		# do nothing
	}
	elsif ($::Variable->{UPS_COUNTRY_REMAP} =~ /=/) {
		my $new = Vend::Util::get_option_hash($::Variable->{UPS_COUNTRY_REMAP});
		Vend::Util::get_option_hash(\%exception, $new);
	}
	else {
		Vend::Util::hash_string($::Variable->{UPS_COUNTRY_REMAP}, \%exception);
	}

	$country = $exception{$country} if $exception{$country};

	# In the U.S., UPS only wants the 5-digit base ZIP code, not ZIP+4
	$country eq 'US' and $zip =~ /^(\d{5})/ and $zip = $1;


##Leaving Cache functions in from ups_query tag 

	my $cache;
	my $cache_code;
	my $db;
	my $now;
	my $updated;
	my %cline;
	my $shipping;
	my $zone;
	my $error;

	my $ctable = $opt->{cache_table} || 'ups_cache';
	my $no_cache = $opt->{no_cache} || $::Variable->{UPS_NO_CACHE};

	if(!$no_cache and $Vend::Database{$ctable}) {
		$Vend::WriteDatabase{$ctable} = 1;
		CACHE: {
			$db = dbref($ctable)
				or last CACHE;
			my $tname = $db->name();
			$cache = 1;
			%cline = (
				weight => $weight,
				origin => $origin,
				country => $country,
				zip	=> $zip,
				shipmode => $mode,
				is_res => $is_res,
			);

			my @items;
			# reverse sort makes zip first
			for(reverse sort keys %cline) {
				push @items, "$_ = " . $db->quote($cline{$_}, $_);
			}

			my $string = join " AND ", @items;
			my $q = qq{SELECT code,cost,updated from $tname WHERE $string};
#::logDebug("in cache query:$q");
			my $ary = $db->query($q);
			if($ary and $ary->[0] and $cache_code = $ary->[0][0]) {
				$shipping = $ary->[0][1];
				$updated = $ary->[0][2];
				$now = time();
				if($now - $updated > 86000) {
					undef $shipping;
					$updated = $now;
				}
				elsif($shipping <= 0) {
					$error = $shipping;
					$shipping = 0;
				}
			}
		}
	}

	my $w = $weight;
	my $maxcost;
	my $tmpcost;

## Perform live query, nothing in cache
## Net::UPS has cache ability, look into that in future
#::logDebug("before lookup after cache shipping:$shipping");

	unless(defined $shipping) {

		my $ups;
#::logDebug("making new: user:$userid pass:$pw key:$accesskey args\n:" . uneval(\%args));
		$ups = Net::UPS->new($userid, $pw, $accesskey, \%args);

		my $servicemode = $service{$mode} || $mode;


#::logDebug("making address city:$city\n state:$state\n zip:$zip\n country:$country\n isres:$is_res");
#::logDebug("making from address city:$o_city\n state:$o_state\n zip:$o_zip\n country:$o_country\n");

		my $from_address;
		if ($o_city && $o_state && $o_zip && $o_country){

			$from_address = Net::UPS::Address->new( city => $o_city,
													 state => $o_state,
													 postal_code => $o_zip,
													 country_code => $o_country,
													);
		}
		else {
			$from_address = $origin;
		}

		my $to_address = Net::UPS::Address->new( city => $city,
												 state => $state,
												 postal_code => $zip,
												 country_code => $country,
												 is_residential => $is_res
												);

		my $package = Net::UPS::Package->new( weight => $weight,
												 length => $length,
												 width => $width,
												 height => $height,
												 packaging_type => $pkg_type,
												);

##Only looking for display of rates and times

		my $quiet;

		if ($opt->{shop_for_rates}){
			my $ctab = 'country';
			$db = dbref($ctab)
				or die "No country table found";
			my $state_key = dbref('state')->foreign($state,'state');
			my $state_modes;
			$state_modes = dbref('state')->field($state_key, 'shipmodes') if $state_key;

			my @ic_allowed_codes = split " ", ($state_modes || $db->field($country,'shipmodes'));
			for(@ic_allowed_codes) {
				s/ups([A-Z]+)/$1/;
			}
#::logDebug("ic_allowed_codes = " . join ',',@ic_allowed_codes);
			my %mv_shipmodes;

			my @limit_to = grep $service{$_}, @ic_allowed_codes;
			my @converted = map { $service{$_} } @limit_to;

			@mv_shipmodes{@converted} = @limit_to;

			my $lt = \@converted;
			
			my $services; 
			eval { 
					$services = $ups->shop_for_rates($from_address, $to_address, $package,
											{limit_to => $lt } );
			};

#::logDebug("was eval error: %s", $@);
#::logDebug("was net error: %s", $ups->errstr);
			$quiet = 1 if $services;

			my @out;
			my $v_shipmode = $::Values->{mv_shipmode};


			if ($opt->{sfr_withoptions}){
				foreach (@$services ) {
					my $selected;
					my $label= $_->label;
					my $mvcode = $mv_shipmodes{$label};
					$v_shipmode =~ /$mvcode/ ? ($selected='selected') : ($selected = '');
					my $cost = $_->total_charges;
					$cost = Vend::Util::currency($cost);
					my $days;
					my $daylabel;
					if ( $days = $_->guaranteed_days() ) {
						my $s = ($days > 1) ? "s" : "";
						$daylabel = qq| - delivers in $days day$s|;
					}
					elsif ($mvcode =~ /upsg/){
						$daylabel = qq| - delivers in 2-7 days|;
					}

					$daylabel = '' unless $country =~ /^US$/;
					my $option_line = <<EOF;
						<option value="$mvcode" $selected>$label ($cost$daylabel) </option>
EOF
					push @out, $option_line; 
				}
			}
			else {
				push @out, "<div>";
				foreach (@$services ) {
					my $label= $_->label;
					my $mvcode = $mv_shipmodes{$label};
#::logDebug("mvcode = $mvcode");
					my $cost = $_->total_charges;
					$cost = Vend::Util::currency($cost);
					my $days;
					my $daylabel;
					if ( $days = $_->guaranteed_days() ) {
						my $s = ($days > 1) ? "s" : "";
						$daylabel = qq|(delivers in $days day$s)|;
					}
					elsif ($mvcode =~ /upsg/){
						$daylabel = qq|(delivers in 2-7 days)|;
					}

					my $line = <<EOF;
						<div>
							$label $cost $daylabel
						</div>
EOF
					push @out, $line; 
				}
				push @out, "</div>";
			}

			return join "\n", @out;
		}


		$shipping = 0;

#		while($w > $modulo) {
#			$w -= $modulo;
#			if($maxcost) {
#				$shipping += $maxcost;
#				next;
#			}
#
#			my $rate;
#
#			eval { 
#				$rate = $ups->rate($origin, $to_address, $package, {service => $servicemode,});	
#			};
#
#			unless (defined $rate ){
#				$Vend::Session->{ship_message} .= " $mode ";
#				$Vend::Session->{ship_message} .= $ups->errstr;
#				return 0;
#			}
#
#			$maxcost = $rate->total_charges();
#
#			$shipping += $maxcost;
#		}
#
		undef $error;

		my $tmprate; 
		eval { 
				$tmprate = $ups->rate($from_address, $to_address, $package, 
										{service => $servicemode});
		};

#::logDebug("was eval error: %s", $@);
#::logDebug("was net error: %s", $ups->errstr);

		unless (defined $tmprate && !$quiet) {
			my $uer = $ups->errstr;
			if( $uer =~ /^The postal code/) {
				$Vend::Session->{ship_message} .= $uer;
			}
			else {
				$Vend::Session->{ship_message} .= "UPS $mode: ";
				$Vend::Session->{ship_message} .= $ups->errstr;
			}
#::logDebug("ship_message:$Vend::Session->{ship_message}");
			return 0;
		}

##warnings passed as well so get them if it exists

		if(my $uer = $ups->errstr) {
			my $vsm = $Vend::Session->{ship_message} || 'xxxx';

			if ( $vsm =~ /$uer/i){
				#do not want duplicate messages
			}
			else{
#				$Vend::Session->{ship_message} .= $ups->errstr;
#				$Vend::Session->{ship_message} .= '. ';
			}
		}

		if (my $os = $package->is_oversized()){
			my $osm = qq("Your package is classed as oversized level $os\n");
			$Vend::Session->{ship_message} .= $osm;
		}

		my $ncost = $tmprate->service()->negotiated_total_charges();
		my $cost = $tmprate->total_charges();

		if ($negotiated_rates){
			$tmpcost = $ncost;
		}
		else {
			$tmpcost = $cost;
		}
#::logDebug("normal cost:$cost negot cost:$ncost using:$tmpcost");
		my $gdays = $tmprate->service()->guaranteed_days();

		$shipping += $tmpcost;

		if($cache and $shipping) {
			$cline{updated} = $now || time();
			$cline{cost} = $shipping || $error;
#::logDebug("would set cache:$cache_code vals:".  uneval(\%cline));
			$db->set_slice($cache_code, \%cline);
		}
	}
#::logDebug("returning cost:$shipping");
#::logDebug("last message:$Vend::Session->{ship_message}");
	if($error) {
		$Vend::Session->{ship_message} .= " UPS $mode: $error";
		return 0;
	}

	return $shipping;
}
EOR

UserTag  ups-net-query  Documentation <<EOD

=head1 NAME

ups-net-query tag -- calculate UPS costs via www

=head1 SYNOPSIS

  [ups-net-query
     weight=NNN
     mode=MODE
     length=NNN*
     width=NNN*
     height=NNN*
     pkg_type=PACKAGE*
     origin=45056*
     zip=61821*
     country=US*
     aggregate=N*
  ]
	
=head1 Example use in the shipping.asc file:

upsg: UPS Ground
    crit            weight
    at_least        5
    adder           0
    ui_ship_type    UPSE:GNDRES
    PriceDivide     1
    service         GND
    aggregate       150

    min             0
    max             0
    cost            e Nothing to ship!

    min             0
    max             1000
	cost            f [ups-net-query zip="[value zip]" mode="upsg" weight="@@TOTAL@@" ]

    min             1000
    max             999999999
    cost            e Too heavy for UPS

=head1 Example uses in shipping pages

Also added ability to output either a display of potential rates, or a list of options formatted to be placed inside of a <select> widget. Examples:

Display only:

[ups-net-query zip="[value zip]"  weight="[weight]" shop_for_rates=1]

Will output a display of possible methods and rates, using the current "country" value in the Values hash, and the allowed ups methods that are in the country table... like such for US, if country had upsg, upsb, and upsr as allowed in the country table:

<div>
	<div> GROUND 13.74 </div>
	<div> 2ND_DAY_AIR 39.49 (delivers in 2 days) </div>
	<div> NEXT_DAY_AIR 83.38 (delivers in 1 day) </div>
</div>

Display options, this code:

<select name=mv_shipmode id=mv_shipmode>
	[ups-net-query zip="[value zip]"  weight="[weight]" shop_for_rates=1 sfr_withoptions=1]
</select>

Will output a display of possible methods and rates, formatted as options, using the current "country" value in the Values hash, and the allowed ups methods that are in the country table... like such for US, if country had upsg, upsb, and upsr as allowed in the country table:

<select id="mv_shipmode" name="mv_shipmode">
	<option value="upsg">GROUND ($13.74) </option>
	<option value="upsb">2ND_DAY_AIR ($39.49 - delivers in 2 days) </option>
	<option value="upsr">NEXT_DAY_AIR ($83.38 - delivers in 1 day) </option>
</select>


=head1 DESCRIPTION

Calculates UPS costs via the WWW using NET::UPS.

Install modified Net::UPS modules from lib/Net/ into your Interchange installation in the same location.

Options:

=over 4

=item weight

Weight in pounds. (required)

=item mode

Any valid Net::UPS mode (required). Example: 1DA,2DA,GNDCOM
           +------------------------+-----------+
           |    SYMBOLIC NAMES      | UPS CODES |
           +------------------------+-----------+
           | NEXT_DAY_AIR           |    01     |
           | 2ND_DAY_AIR            |    02     |
           | GROUND                 |    03     |
           | WORLDWIDE_EXPRESS      |    07     |
           | WORLDWIDE_EXPEDITED    |    08     |
           | STANDARD               |    11     |
           | 3_DAY_SELECT           |    12     |
           | NEXT_DAY_AIR_SAVER     |    13     |
           | NEXT_DAY_AIR_EARLY_AM  |    14     |
           | WORLDWIDE_EXPRESS_PLUS |    54     |
           | 2ND_DAY_AIR_AM         |    59     |
           | UPS_SAVER              |    65     |
           +------------------------+-----------+

Will provide hash conversion for current IC methods from Business::UPS

1DM           Next Day Air Early AM
  1DML          Next Day Air Early AM Letter
  1DA           Next Day Air
  1DAL          Next Day Air Letter
  1DP           Next Day Air Saver
  1DPL          Next Day Air Saver Letter
  2DM           2nd Day Air A.M.
  2DA           2nd Day Air
  2DML          2nd Day Air A.M. Letter
  2DAL          2nd Day Air Letter
  3DS           3 Day Select
  GNDCOM        Ground Commercial
  GNDRES        Ground Residential
  XPR           Worldwide Express
  XDM           Worldwide Express Plus
  XPRL          Worldwide Express Letter
  XDML          Worldwide Express Plus Letter
  XPD           Worldwide Expedited


=item length optional

One of 3 dimensional listings, recommend all 3 supplied for accurate quotes.
Default set to 1"

=item width optional

One of 3 dimensional listings, recommend all 3 supplied for accurate quotes.
Default set to 1"

=item height optional

One of 3 dimensional listings, recommend all 3 supplied for accurate quotes.
Default set to 1"

=item pkg_type optional

Default set to 'PACKAGE'

Possible values: 

        LETTER          
        PACKAGE*         
        TUBE            
        UPS_PAK         
        UPS_EXPRESS_BOX 
        UPS_25KG_BOX    
        UPS_10KG_BOX    


=item origin optional if variable valid

Origin zip code. Default is $Variable->{UPS_ORIGIN}.

=item o_* optional but recommended. Should be set in variables.

	o_city
	o_state
	o_zip
	o_country

Origin values. For accurate quotes and for some international queries, add origin city, state, zip, and country. IF not set, quote will derive from UPS_ORIGIN zip only. Set variables as follows for defaults :

	$::Variable->{UPS_O_CITY}
	$::Variable->{UPS_O_STATE}
	$::Variable->{UPS_O_COUNTRY_FIELD}
	$::Variable->{UPS_O_POSTCODE_FIELD}
					


=item city optional

Destination city. Default $Values->{city}.


=item state optional

Destination state. Default $Values->{state}.


=item zip optional

Destination zip code. Default $Values->{zip}.


=item country optional

Destination country. Default $Values->{country}.


=item residential optional

Destination address status. Default $Values->{mv_ship_residential}.


=item aggregate

If 1, aggregates by a call to weight=150 (or $Variable->{UPS_QUERY_MODULO}).
Multiplies that times number necessary, then runs a call for the
remainder. In other words:

	[ups-net-query weight=400 mode=GNDCOM aggregate=1]

is equivalent to:

	[calc]
		[ups-net-query weight=150 mode=GNDCOM] + 
		[ups-net-query weight=150 mode=GNDCOM] + 
		[ups-net-query weight=100 mode=GNDCOM];
	[/calc]

If set to a number above 10, will be the modulo to do repeated calls by. So:

	[ups-net-query weight=400 mode=GNDCOM aggregate=100]

is equivalent to:

	[calc]
		[ups-net-query weight=100 mode=GNDCOM] + 
		[ups-net-query weight=100 mode=GNDCOM] + 
		[ups-net-query weight=100 mode=GNDCOM] + 
		[ups-net-query weight=100 mode=GNDCOM];
	[/calc]

=item cache_table

Set to the name of a table (default ups_cache) which can cache the
calls so repeated calls for the same values will not require repeated
calls to UPS.

Table needs to be set up with:

	Database   ups_cache    ship/ups_cache.txt         __SQLDSN__
	Database   ups_cache    AUTO_SEQUENCE  ups_cache_seq
	Database   ups_cache    DEFAULT_TYPE varchar(12)
	Database   ups_cache    INDEX  weight origin zip shipmode country

And have the fields:

	 code weight origin zip country shipmode cost updated is_res

Typical cached data will be like:

	code	weight	origin	zip	country	shipmode	cost	updated	is_res
	14	11	45056	99501	US	2DA	35.14	1052704130
	15	11	45056	99501	US	1DA	57.78	1052704130
	16	11	45056	99501	US	2DA	35.14	1052704132
	17	11	45056	99501	US	1DA	57.78	1052704133

Cache expires in one day.

=back

EOD
