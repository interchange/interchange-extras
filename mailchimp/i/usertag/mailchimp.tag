UserTag mailchimp Order method
UserTag mailchimp addAttr
UserTag mailchimp Description MailChimp interaction via their API
UserTag mailchimp Routine <<EOR
require LWP::UserAgent;
use JSON;
sub {
	my ($method, $opt) = @_;

	use vars qw/$Tag/;
	my ($log, $die, $warn) = $Tag->logger('mailchimp', 'logs/mailchimp.log');

	if (delete $opt->{queue}) {
		my $qdb = dbref('mailchimp_queue')
			or return $die->('no queue table');
		$qdb->set_slice(undef, { method => $method, opt => uneval($opt) });
$log->("queued $method, opts were: " . uneval($opt) );
		return $opt->{hide} ? undef : 1;
	}

#use Data::Dumper;
	my %api = (
		campaigns => {
			list => {
				filters => {
					campaign_id => q{},
					parent_id => q{},
					list_id => q{},
					folder_id => q{},
					template_id => q{},
					status => q{},
					type => q{},
					from_name => q{},
					from_email => q{},
					title => q{},
					subject => q{},
					sendtime_start => q{},
					sendtime_end => q{},
					uses_segment => 1,
					exact => 1,
				},
				start => 0,
				limit => 25,
				sort_field => q{create_time},
				sort_dir => q{DESC},
			},
		},
		ecomm => {
			'order-add' => {
				order => {
					id => q{},
					campaign_id => q{},
					email_id => q{},
					email => q{},
					total => q{},
					order_date => q{},
					shipping => q{},
					tax => q{},
					store_id => q{},  # 32 bytes max
					store_name => q{},
					items => [
						{
							line_num => q{},    # one hash for each line item in cart
							product_id => q{},  # integer
							sku => q{},         # max 30 bytes
							product_name => q{},
							category_id => q{},     # integer
							category_name => q{},   # could be: "Root - SubCat1 - SubCat4", etc
							qty => 1,
							cost => 0,
						},
					],
				},
			},
			'order-del' => {
				store_id => q{},
				order_id => q{},
			},
			orders => {
				cid => q{},
				start => 0,
				limit => 100,
				since => q{},
			},
		},
		lists => {
			list => {
				filters => {
					list_id => q{},
					list_name => q{},
					from_name => q{},
					from_email => q{},
					from_subject => q{},
					created_before => q{},
					created_after => q{},
					exact => 1,
				},
				start => 0,
				limit => 25,
				sort_field => q{},
				sort_dir => q{DESC},
			},
			'member-info' => {
				id => q{},
				emails => [
					{
						email => q{},
						euid => q{},
						leid => q{},
					},
				],
			},
			members => {
				id => q{},
				status => q{subscribed},
				opts => {
					start => 0,
					limit => 25,
					sort_field => q{},
					sort_dir => q{ASC},
					segment => {
					},
				},
			},
			'merge-vars' => {
				id => [
				],
			},
			segments => {
				id => q{},
				type => q{},  # 'static' or 'saved'
			},
			subscribe => {
				id => q{},
				email => {
					email => q{},
					euid => q{},
					leid => q{},
				},
				merge_vars => {
					'new-email' => q{},
					groupings => [
						{
							id => q{},
							name => q{},
							groups => [ {} ],
						}
					],
					optin_ip => q{},
					optin_time => q{},
					mc_location => {
						latitude => q{},
						longitude => q{},
						anything => q{},
					},
					mc_language => q{},
					mc_notes => [
						{
							note => q{},
							id => q{},
							action => q{},
						},
					],
				},
				email_type => q{html},
				double_optin => 1,
				update_existing => 0,
				replace_interests => 1,
				send_welcome => 0,
			},
			unsubscribe => {
				id => q{},
				email => {
					email => q{},
					euid => q{},
					leid => q{},
				},
				delete_member => 0,
				send_goodbye => 1,
				send_notify => 1,
			},
## can't get merge_vars working for update-member method.
#			'update-member' => {
#				id => q{},
#				email => {
#					email => q{},
#					euid => q{},
#					leid => q{},
#				},
#				merge_vars => [ {} ],
#				email_type => q{},
#				replace_interests => 1,
#			},
		},
	);
#print Dumper(\%api);

	my ($section, $call) = split '/', $method;

	my $struct = $api{$section}{$call}
		or return $die->('Unsupported method: %s', $method);

	## add merge_vars to struct:
	if ($opt->{merge_vars}) {
		while (my ($k,$v) = each %{$opt->{merge_vars}} ) {
			$struct->{merge_vars}{$k} = $v if $call eq 'subscribe';
			$struct->{merge_vars}[0]{$k} = $v if $call eq 'update-member';
		}
	}

#$log->("struct is: " . ::uneval($struct) );
#$log->("opt is: " . uneval($opt) );

	## legacy support:
	if (my $email = $opt->{email_address} and $call =~ /subscribe$/) {
		$opt->{email}{email} = $email;
	}
	
	while (my ($k,$v) = each %$struct) {    # struct should be a hash. Step through and set from the passed $opt values.
		my $passed = defined $opt->{$k} ? $opt->{$k} : undef;
		unless (defined $passed) {
			delete $struct->{$k};
			next;
		}
		if (ref $v eq 'HASH') {   # step through the next level.
			while (my ($subk, $subv) = each %$v) {
				my $sub_passed = defined $opt->{$k}{$subk} ? $opt->{$k}{$subk} : undef;
				unless (defined $sub_passed) {
					delete $struct->{$k}{$subk};
					next;
				}
				$struct->{$k}{$subk} = $sub_passed;
			}
			delete $struct->{$k} unless keys %$v;   # after while(), remove parent key if nothing inside
		}
		elsif (ref $v eq 'ARRAY') {
			if (ref $v->[0] eq 'HASH') {   # array has (we presume) a single-element: a hash
				while (my ($subk, $subv) = each %{$v->[0]} ) {
					my $sub_passed = defined $opt->{$k}{$subk} ? $opt->{$k}{$subk} : undef;
					unless (defined $sub_passed) {
						delete $struct->{$k}[0]{$subk};
						next;
					}
					$struct->{$k}[0]{$subk} = $sub_passed;
				}
			}
			else {   # must be an array of strings
				my $sub_passed = defined $opt->{$k} ? $opt->{$k} : undef;
				$struct->{$k} = $sub_passed;
			}
		}
		else {
			$struct->{$k} = $passed;
		}
	}

#$log->("struct is now: " . ::uneval($struct) );

	$struct->{apikey} = $::Variable->{MAILCHIMP_API_KEY}
		or return $die->("No API key");
	my $dash       = rindex($struct->{apikey}, '-');
	my $datacenter = $dash ? substr($struct->{apikey}, ($dash+1)) : 'us1';
	my $output_fmt = $opt->{output} || 'json';
	my $api_url    = qq{https://$datacenter.api.mailchimp.com/2.0/$section/$call.$output_fmt};

	my $json = encode_json($struct);
#$log->("json: " . $json);

	my $req = HTTP::Request->new(POST => $api_url);
	$req->content_type('application/json');
	$req->content($json);

	my $ua = LWP::UserAgent->new( timeout => $opt->{timeout} || 15, agent => 'Interchange' );
	my $res = $ua->request($req);

#return ::uneval(%$res);  # for testing

	my $out = $res->content;
	   $out = decode_json($out);

	if ($res->is_success) {
$log->("performed $method. response: " . uneval($out) );
		if ($opt->{return_ref}) {
			return $out;
		}
		else {
			return $opt->{hide}
					? $log->("json was: $json")
					: ::uneval($out) . "\njson was: $json"
				;
		}
	}
	else {
		my $err = "Code: $out->{code}, $out->{name}. $out->{error}" . "\njson was: $json";
		return $opt->{hide} ? $log->($err) : $die->($err);
	}
}
EOR
UserTag mailchimp Documentation <<EOD

=head1 NAME

mailchimp -- interact with MailChimp API v2.0

=head1 DESCRIPTION

Read the code to see what actions it supports explicity. API docs are here:
L<http://apidocs.mailchimp.com/api/2.0/>

More actions may be defined by altering the %api hash. Not all actions may work, even if defined.

It only handles JSON output at this point.

=head1 USAGE

Examples:

=over 4

[mailchimp method="lists/list"]

[mailchimp method="lists/members" id="123abc"]

[mailchimp method="lists/member-info" id="123abc" emails.email="foo@bar.com"]

[mailchimp method="lists/subscribe" id="123abc" email-address="foo@bar.com"]

[mailchimp method="lists/subscribe" id="123abc" email.email="foo@bar.com" merge_vars.fname="Foo" update-existing=1]

(B<lists/subscribe> and B<lists/unsubscribe> will translate the email-address option to email.email)

=back

Add a new variable to F<CATROOT/products/variable.txt>:

	MAILCHIMP_API_KEY

and set to the value of the API key you generate here:
L<https://admin.mailchimp.com/account/api>

To call from Perl, you must use global=1, and structure like so:

	[perl global=1]
		my $res = $Tag->mailchimp({
			method => 'lists/subscribe',
			id => '123abc',
			email => {
				email => 'foo@bar.com',
			},
			merge_vars => {
				fname    => 'Sum',
				lname    => 'Gui',
			},
			send_welcome => 0,
		});
		return $res;
	[/perl]

=head1 PREREQUISITES

logger.tag,
LWP::UserAgent,
JSON

=head1 MERGE VARS

If you want to use ITL in references for your merge_vars, such as:

	[mailchimp ... merge_vars.optin_ip="[data session host]"]

Then you need to surround the [mailchimp] tag with a pragma, like so:

	[tag pragma interpolate_itl_references]1[/tag]
	[mailchimp ... merge_vars.optin_ip="[data session host]"]
	[tag pragma interpolate_itl_references]0[/tag]

You cannot apparently use things like "[time]%Y%m%d[/time]" as a
merge_var. The [either] tag appears to work fine, though. Be sure to
test to ensure it is getting interpolated.

merge_vars can be found in your list's merge tags, or via the B<lists/merge-vars>
method. You apparently don't have to send them in all uppercase.
You can also use the special merge_vars keys found in the API
documentation for B<lists/subscribe> (link above).

=head1 BUGS

The usual number.

=head1 COPYRIGHT

Copyright (C) 2012-2014 Josh Lavin. All rights reserved.

This usertag is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Josh Lavin -- Perusion

=cut
EOD
