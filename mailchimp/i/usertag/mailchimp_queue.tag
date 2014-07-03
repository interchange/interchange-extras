UserTag mailchimp_queue Routine <<EOR
sub {
	my $qdb = dbref('mailchimp_queue')
		or die 'no mailchimp_queue table';

	use vars qw/$Tag $ready_safe/;
	my ($log, $die, $warn) = $Tag->logger('mailchimp_queue', 'logs/mailchimp_queue.log');

## MailChimp:
	my $mcq = q{SELECT * FROM mailchimp_queue WHERE processed = 0 AND type = 'mailchimp'};
	my $q_ary = $qdb->query({ sql => $mcq, hashref => 1 });
	for my $q (@$q_ary) {
		my $opt = $ready_safe->reval( $q->{opt} );
		delete $opt->{hide};
		my $res = $Tag->mailchimp( $q->{method}, $opt );
		$qdb->set_field($q->{code}, 'processed', 1) if $res;
$log->("mailchimp: $res") if $res;
	}

## Mandrill:
	my $mnq = q{SELECT * FROM mailchimp_queue WHERE processed = 0 AND type = 'mandrill'};
	my $mnq_ary = $qdb->query({ sql => $mnq, hashref => 1 });
	for my $q (@$mnq_ary) {
		my $opt = $ready_safe->reval( $q->{opt} );
		delete $opt->{hide};
		my $res = $Tag->mandrill( $q->{method}, $opt );
		$qdb->set_field($q->{code}, 'processed', 1) if $res;
$log->("mandrill: $res") if $res;
	}

## delete:
	my $week_ago = $Tag->time({ fmt => '%Y-%m-%d', adjust => '-1 week' });
	my $del_ary = $qdb->query("DELETE FROM mailchimp_queue WHERE processed = 1 AND last_modified < '$week_ago'");
$log->("Deleted $del_ary old records.") if $del_ary;

	return;
}
EOR
