UserTag mailchimp Order method
UserTag mailchimp addAttr
UserTag mailchimp Description MailChimp subscribe/unsubscribe via API
UserTag mailchimp Routine <<EOR
require LWP::UserAgent;
use JSON;
sub {
	my ($func, $opt) = @_;

	use vars qw/$Tag/;

    my $default = sub {
        my $thing = shift;
        return $thing->(@_) if ref($thing) eq 'CODE';
        return $thing;
    };

	my %func = (
		ecommOrderAdd => {
			parameters => {qw/
				method   method
				order    order
				/
			},
		},
		ecommOrders => {
			parameters => {qw/
				method   method
				start    start
				limit    limit
				since    since
				/
			},
		},
		listMembers => {
			parameters => {qw/
				method    method
				id        id
				status    status
				since     since
				start     start
				limit     limit
				sort_dir  sort_dir
				/
			},
			default => {
				status   => 'subscribed',
				start    => 0,
				limit    => 100,
				sort_dir => 'ASC',
			},
		},
		listSubscribe => {
			parameters => {qw/
				method              method
				id                  id
				email_address       email_address
				merge_vars          merge_vars
				email_type          email_type
				double_optin        double_optin
				update_existing     update_existing
				replace_interests   replace_interests
				send_welcome        send_welcome
				/
			},
			default => {
				update_existing => 1,
			},
		},
		listUpdateMember => {
			parameters => {qw/
				method               method
				id                   id
				email_address        email_address
				merge_vars           merge_vars
				email_type           email_type
				replace_interests    replace_interests
				/
			},
			default => {
				replace_interests => 1,
			},
		},
		listUnsubscribe => {
			parameters => {qw/
				method          method
				id              id
				email_address   email_address
				delete_member   delete_member
				send_goodbye    send_goodbye
				send_notify     send_notify
				/
			},
			default => {
				send_goodbye => 1,
				send_notify => 1,
			},
		},
		lists => {
			parameters => {qw/
				method    method
				filters   filters
				start     start
				limit     limit
				/
			},
		},
	);
	my ($log, $die, $warn) = $Tag->logger($opt->{logname} || 'mailchimp', $opt->{logfile} || 'logs/mailchimp.log');

	my $struct = $func{$func}
		or return $die->('Unsupported method');
	
	my $parm = $struct->{parameters}
		or return $die->('Bad function %s', $func);
	my $def = $struct->{default} || {};

	my %arg;
	while( my ($k, $v) = each %$parm) {
		my $val = $opt->{$v};
		if(! length($val) and $def->{$k}) {
			$val = $default->($def->{$k}, $val);
		}
		if($k =~ /merge_vars/ and length($val)) {
			for(keys %$val) {
				$arg{'merge_vars[' . uc $_ . ']'} = $val->{$_};
			}
		}
		else {
			$arg{$k} = $val if length($val);
		}
	}
my @merge_args = map { $_ =~ s/^merge_vars// ? ($_ .'='. $arg{"merge_vars$_"}) : '' } keys %arg;
@merge_args = grep { /\S/ } @merge_args;

	my $api_key = $::Variable->{MAILCHIMP_API_KEY};
	my $dash = rindex($api_key, '-');
	my $datacenter = $dash ? substr($api_key, ($dash+1)) : 'us1';
	my $sec = $opt->{secure} =~ /^0|no/ ? '' : 's';
	my $api_url = 'http' . $sec . '://' . $datacenter . '.api.mailchimp.com/1.3/';
	my $output_fmt = $opt->{output} || 'json';

	$arg{apikey} = $api_key;

	my $ua = LWP::UserAgent->new( timeout => $opt->{timeout} || 5, agent => $opt->{agent} || 'Interchange' );

#$log->("args are: " . ::uneval(\%arg));
	my $response = $ua->post($api_url . '?method=' . $arg{method}, \%arg);
#return ::uneval(%$response);  # for testing

	my $out;
	if ($response->is_success) {
		$out = $response->content;
	}
	if(!$out or $out =~ /error/) {
		return $opt->{hide} ? $log->($out) : $die->($out);
	}
$log->("performed $arg{method} on $arg{email_address}. response: $out, merge_vars: " . join ', ', @merge_args);

	$out = ::uneval(decode_json($out)) if ref($out) eq 'HASH';
	return $opt->{hide} ? '' : $out;
}
EOR
UserTag mailchimp Documentation <<EOD

=head1 NAME

mailchimp -- interact with MailChimp API v1.3

=head1 DESCRIPTION

Read the code to see what actions it supports explicity. API docs are here:

	http://apidocs.mailchimp.com/api/1.3/

It only uses JSON output at this point.

*** We are no longer setting the fname and lname from Values space.

Usage:

=over 4

[mailchimp method=listSubscribe id="" email_address=""]

Add a new variable to C<CATROOT/products/variable.txt>:

	MAILCHIMP_API_KEY

and set to the value of the API key you generate here:

	<https://admin.mailchimp.com/account/api>

=back

=head1 PREREQUISITES

logger.tag,
LWP::UserAgent,
JSON

If you want to use ITL in references for your merge_vars, such as:

	[mailchimp ... merge_vars.optin_ip="[data session host]"]

Then you need to surround the [mailchimp] tag with a pragma, like so:

	[tag pragma interpolate_itl_references]1[/tag]
	[mailchimp ... merge_vars.optin_ip="[data session host]"]
	[tag pragma interpolate_itl_references]0[/tag]

merge_vars can be found in your list's merge tags, and are automatically
uppercased by this tag. You can also use merge_vars found in the API
documentation (link above).

To call from Perl, you must use global=1, and structure like so:

	[perl global=1]
		my $chimp = $Tag->mailchimp({
			method => 'listSubscribe',
			id => '123abc',
			email_address => 'foo@bar.com',
			merge_vars => {
				fname    => 'Sum',
				lname    => 'Gui',
			},
			send_welcome => 0,
		});
		return;
	[/perl]

=head1 BUGS

The usual number.

=head1 COPYRIGHT

Copyright (C) 2012 Josh Lavin. All rights reserved.

This usertag is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Josh Lavin

EOD
