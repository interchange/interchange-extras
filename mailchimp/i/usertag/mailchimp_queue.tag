UserTag mailchimp_queue Routine <<EOR
sub {
    my $qdb = dbref('mailchimp_queue')
        or die 'no mailchimp_queue table';

    use vars qw/$Tag $ready_safe/;
    my ($log, $die, $warn) = $Tag->logger('mailchimp_queue', 'logs/mailchimp_queue.log');

## Mandrill:
    my $mnq = q{SELECT * FROM mailchimp_queue WHERE processed = 0 AND type = 'mandrill'};
    my $mnq_ary = $qdb->query({ sql => $mnq, hashref => 1 });
    for my $q (@$mnq_ary) {
        my $opt = $ready_safe->reval( $q->{opt} ) || {};
        $opt->{really_die} = 1;
        delete $opt->{hide};
        $q->{tries} >= 2 and do {
            $qdb->set_field($q->{code}, 'processed', 1);
            next;
        };
        my $res;
        eval {
            $res = $Tag->mandrill( $q->{method}, $opt ) || '';
        };
        if ($@) {
            my $e = $@;
            $qdb->set_field( $q->{code}, 'tries', $q->{tries} + 1 );
            $die->('call to mandrill.tag for code %s: %s', $q->{code}, $e);
            next;
        }
        $qdb->set_field($q->{code}, 'processed', 1) if $res;
$log->("mandrill: $res") if $res;
    }

## MailChimp:
    my $mcq = q{SELECT * FROM mailchimp_queue WHERE processed = 0 AND type = 'mailchimp'};
    my $q_ary = $qdb->query({ sql => $mcq, hashref => 1 });
    for my $q (@$q_ary) {
        my $opt = $ready_safe->reval( $q->{opt} ) || {};
        delete $opt->{hide};
        my $res;
        eval {
            $res = $Tag->mailchimp( $q->{method}, $opt ) || '';
        };
        if ($@) {
            my ($e, $status);
            $e = $@;
            $e =~ /'status' => 400/ and $status = 400;
            $status and $qdb->set_field($q->{code}, 'processed', $status);
            $die->('call to mailchimp.tag for code %s: %s', $q->{code}, $e);
            next;
        }
        $qdb->set_field($q->{code}, 'processed', 1);
$log->("mailchimp: $res");
    }

## delete:
    my $week_ago = $Tag->time({ fmt => '%Y-%m-%d', adjust => '-1 week' });
    my $del_ary = $qdb->query("DELETE FROM mailchimp_queue WHERE processed = 1 AND last_modified < '$week_ago'");
$log->("Deleted $del_ary old records.") if $del_ary;

    return;
}
EOR
