UserTag mandrill_email Order to subject reply from extra
UserTag mandrill_email hasEndTag
UserTag mandrill_email addAttr
UserTag mandrill_email Interpolate
UserTag mandrill_email Description Replacement for [email] tag, except no utf8. It will support HTML, though.
UserTag mandrill_email Routine <<EOR
use MIME::Base64;
use MIME::Types;
sub {
    my ($to, $subject, $reply, $from, $extra, $opt, $body) = @_;
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

	my $attachments = [];
	ATTACH: {
		last ATTACH unless $opt->{attach};

		my $att = $opt->{attach};

		if(! ref($att) ) {
			my $fn = $att;
			$att = [ { path => $fn } ];
		}
		elsif(ref($att) eq 'HASH') {
			$att = [ $att ];
		}
		elsif(ref($att) eq 'ARRAY') {
			# turn array of file names into array of hash references
			my $new_att = [];

			for (@$att) {
				if (ref($_)) {
					push (@$new_att, $_);
				}
				else {
					push (@$new_att, {path => $_});
				}
			}

			$att = $new_att;
		}

		$att ||= [];

		my $mime_types = MIME::Types->new;

		for my $ref (@$att) {
			next unless $ref;
			next unless $ref->{path} || $ref->{data};
			unless ($ref->{filename}) {
				my $fn = $ref->{path};
				$fn =~ s:.*[\\/]::;
				$ref->{filename} = $fn;
			}

			$ref->{type} ||= ( ($mime_types->mimeTypeOf($ref->{filename}) || {})->{MT_type} || 'application/octet-stream' );
		}

		for my $a (@$att) {
			my $data = $a->{data} || $Tag->file( $a->{path} );
			push @$attachments, {
				type    => $a->{type},
				name    => $a->{filename},
				content => encode_base64($data),
			};
		}
		$opt->{queue} = 0;  # database not big enough for attachments
	}

    $reply = '' unless defined $reply;
    $reply = "Reply-to: $reply\n" if $reply;

	push(@extra, "Cc: $cc") if $cc;

	my $ext = {};
	for (@extra) {
		my ($k,$v) = split ': ', $_;
		$ext->{$k} = $v;
	}

	my $from_name;
	$from =~ s/(.*) +<(.*)>/$2/ and $from_name = $1;
	$from_name =~ s/"//g;

	my $to_name;
	$to =~ s/(.*) +<(.*)>/$2/ and $to_name = $1;
	$to_name =~ s/"//g;

	# split out any multiple recipients
	my @emails = split /[,\0]\s*/, $to;
	my $tos = [];
	for my $e (@emails) {
		push @$tos, { email => $e, name => $to_name };
	}

	my $ok;
	eval {
        $ok = $Tag->mandrill({
			method => 'messages/send',
			message => {
				html        => $opt->{html},
				text        => $body,
				subject     => $subject,
				from_email  => $from,
				from_name   => $from_name,
				to          => $tos,
				headers     => $ext,
				bcc_address => $bcc,
				tags        => ref $opt->{tags} ? $opt->{tags} : [ $opt->{tags} ],
				metadata    => ref $opt->{metadata} ? $opt->{metadata} : { $opt->{metadata} },
				attachments => $attachments,
			},
			queue => $opt->{queue},
		});
    };
    return ::logError($@) if $@;

    if (!$ok) {
        ::logError("Unable to send mail using mandrill_email\n" .
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
UserTag mandrill_email Documentation <<EOD

=head1 NAME

mandrill-email -- replacement for Interchange [email] tag. Sends via Mandrill.

=head1 DESCRIPTION

Now supports attachments, limited to 25 MB in size. Since attachments
are Base64-encoded, this generally means that they will be 1/3 larger
when sending than they are on disk due to the encoding.

=head1 USAGE

Examples:

=over 4

[mandrill-email
    to='"[loop-param fname]" <[loop-param email]>'
    subject="Greetings, earthling"
    from='"__COMPANY__" <__EMAIL_SERVICE__>'
    tags="greeting_email"
    metadata.catalog="earth_cat"
    metadata.member_no="[loop-param username]"
    metadata.type="functional"
]Hello, there![/mandrill-email]

=back

If you want to use ITL in your options that are arrays are hashes (e.g.
tags.0="[foo]" or metadata.type="[bar-baz]"), you need to surround the
[mandrill-email] tag with a pragma, like so:

	[tag pragma interpolate_itl_references]1[/tag]
	[mandrill-email ...][/mandrill-email]
	[tag pragma interpolate_itl_references]0[/tag]

=head1 PREREQUISITES

MIME::Base64
MIME::Types

=head1 COPYRIGHT

Copyright (C) 2014-2015 Josh Lavin. All rights reserved.

This usertag is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Josh Lavin -- Perusion

EOD
