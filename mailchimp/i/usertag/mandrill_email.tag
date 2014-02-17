UserTag mandrill_email Order to subject reply from extra
UserTag mandrill_email hasEndTag
UserTag mandrill_email addAttr
UserTag mandrill_email Interpolate
UserTag mandrill_email Description Replacement for [email] tag, except no attachments or utf8. It will support HTML, though.
UserTag mandrill_email Routine <<EOR
sub {
    my ($to, $subject, $reply, $from, $extra, $opt, $body) = @_;
	my $ok = 0;
    my ($cc, $bcc, @extra);

	use vars qw/ $Tag /;

    $subject = '<no subject>' unless defined $subject && $subject;

	if (! $from) {
		$from = $Vend::Cfg->{MailOrderTo};
		$from =~ s/,.*//;
	}

	# Use local copy to avoid mangling with caller's data
	$cc = $opt->{cc};
	$bcc = $opt->{bcc};

	# Prevent header injections from spammers' hostile content
	for ($to, $subject, $reply, $from, $cc, $bcc) {
		# unfold valid RFC 2822 "2.2.3. Long Header Fields"
		s/\r?\n([ \t]+)/$1/g;
		# now remove any invalid extra lines left over
		s/[\r\n](.*)//s
			and ::logError("Header injection attempted in email tag: %s", $1);
	}

	for (grep /\S/, split /[\r\n]+/, $extra) {
		# require header conformance with RFC 2822 section 2.2
		push (@extra, $_), next if /^[\x21-\x39\x3b-\x7e]+:[\x00-\x09\x0b\x0c\x0e-\x7f]+$/;
		::logError("Invalid header given to email tag: %s", $_);
	}

    $reply = '' unless defined $reply;
    $reply = "Reply-to: $reply\n" if $reply;

	push(@extra, "Cc: $cc") if $cc;

	my %ext;
	for (@extra) {
		my ($k,$v) = split ': ', $_;
		$ext{$k} = $v;
	}

	my $from_name;
	$from =~ s/(.*) +<(.*)>/$2/ and $from_name = $1;
	$from_name =~ s/"//g;

	my $to_name;
	$to =~ s/(.*) +<(.*)>/$2/ and $to_name = $1;
	$to_name =~ s/"//g;

	$ok = $Tag->mandrill({
			method => 'messages/send',
			message => {
				html        => $opt->{html},
				text        => $body,
				subject     => $subject,
				from_email  => $from,
				from_name   => $from_name,
				to          => [
						     	{
						     	 email => $to,
						     	 name => $to_name,
						     	}
						       ],
				headers     => [ \%ext ],
				bcc_address => $bcc,
				tags => $opt->{tags} || [],
			},
			queue => $opt->{queue},
		});

    if (!$ok) {
        logError("Unable to send mail using mandrill_email\n" .
            "To '$to'\n" .
            "From '$from'\n" .
            "With extra headers '$extra'\n" .
            "With reply-to '$reply'\n" .
            "With subject '$subject'\n" .
            "And body:\n$body");
    }

	return $opt->{hide} ? '' : $ok;
}
EOR
