UserTag mandrill Order method
UserTag mandrill addAttr
UserTag mandrill Description Mandrill.com transactional emails via their API
UserTag mandrill Routine <<EOR
require LWP::UserAgent;
use JSON;
sub {
	my ($method, $opt) = @_;

	use vars qw/$Tag/;
	my ($log, $die, $warn) = $Tag->logger('mandrill', 'logs/mandrill.log');

	if (delete $opt->{queue}) {
		my $qdb = dbref('mailchimp_queue')
			or return $die->('no queue table');
		$qdb->set_slice(undef, { method => $method, opt => uneval($opt), type => 'mandrill' });
$log->("queued $method, opt-message-to: " . uneval($opt->{message}{to}) );
		return $opt->{hide} ? undef : 1;
	}

#use Data::Dumper;
	my %message = (
		html => q{},
		text => q{},
		subject => q{},
		from_email => q{},
		from_name => q{},
		to => [
			{
				email => q{},
				name => q{},
				type => q{},
			},
		],
		headers => [ {} ],
		important => q{},
		track_opens => q{},   # true by default, but can be changed via "Sending Options" in Mandrill
		track_clicks => q{},  # true by default for HTML mail, but can be changed via "Sending Options" in Mandrill
		auto_text => q{},
		auto_html => q{},
		inline_css => q{},
		url_strip_qs => q{},
		preserve_recipients => q{},
		view_content_link => q{},
		bcc_address => q{},
		tracking_domain => q{},
		signing_domain => q{},
		return_path_domain => q{},
		merge => q{},
		global_merge_vars => q{},
		merge_vars => q{},
		tags => q{},
		subaccount => q{},
		google_analytics_domain => q{},
		google_analytics_campaign => q{},
		metadata => q{},
		recipient_metadata => q{},
		attachments => q{},
		images => q{},
	);
	my %api = (
		messages => {
			send => {
				message => \%message,
				async   => q{},
				ip_pool => q{},
				send_at => q{},
			},
			send_template => {
				template_name => q{},
				template_content => q{},
				message => \%message,
				async   => q{},
				ip_pool => q{},
				send_at => q{},
			},
			info => {
				id => q{},
			},
			content => {
				id => q{},
			},
		},
	);
#print Dumper(\%api);

	my ($category, $call) = split '/', $method;

	my $struct = $api{$category}{$call}
		or return $die->('Unsupported method: %s', $method);

#$log->("struct is: " . uneval($struct) );

	while (my ($k,$v) = each %$struct) {   # struct should be a hash. Step through and set from the passed $opt values.
		my $passed = $opt->{$k} || '';
		unless ($passed) {
			delete $struct->{$k};
			next;
		}
		if (ref $v eq 'HASH') {   # step through the next level.
			while (my ($subk, $subv) = each %$v) {
				my $sub_passed = $opt->{$k}{$subk} || '';
				unless ($sub_passed) {
					delete $struct->{$k}{$subk};
					next;
				}
				if (ref $subv eq 'HASH') {
					## do anything more here?
					$struct->{$k}{$subk} = $sub_passed;
				}
				else {
					$struct->{$k}{$subk} = $sub_passed;
				}
			}
		}
		else {
			$struct->{$k} = $passed;
		}
	}

#$log->("struct is now: " . ::uneval($struct) );

	my $output_fmt = $opt->{output} || 'json';
	$struct->{key} = $::Variable->{MANDRILL_API_KEY} || $::Variable->{MANDRILL_TEST_API_KEY}
		or return $die->("No API key");
	my $api_url = qq{https://mandrillapp.com/api/1.0/$category/$call.$output_fmt};

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
		return $opt->{hide}
				? $log->("json was: $json")
				: ::uneval($out)
			;
	}
	else {
		my $err = "Code: $out->{code}, $out->{name}. $out->{message}";
		return $opt->{hide} ? $log->($err) : $die->($err);
	}
}
EOR
UserTag mandrill Documentation <<EOD

=head1 NAME

mandrill -- interact with Mandrill Transactional Email Service, API v1.0

=head1 DESCRIPTION

Read the code to see what actions it supports explicity. API docs are here:
L<https://mandrillapp.com/api/docs/>

More actions may be defined by altering the %api hash. Not all actions may work, even if defined.

It only handles JSON output at this point.

=head1 USAGE

Examples:

=over 4

[mandrill method="messages/info" id="123abc"]

=back

Add a new variable to F<CATROOT/products/variable.txt>:

	MANDRILL_API_KEY

and set to the value of the API key you generate here:
L<https://mandrillapp.com/settings/index>

To call from Perl, you must use global=1, and structure like so:

	[perl global=1]
		my $res = $Tag->mandrill({
			method => 'info',
			id => '123abc',
		});
		return $res;
	[/perl]

=head1 PREREQUISITES

logger.tag,
LWP::UserAgent,
JSON

=head1 BUGS

The usual number.

=head1 COPYRIGHT

Copyright (C) 2014 Josh Lavin. All rights reserved.

This usertag is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Josh Lavin -- Perusion

EOD
