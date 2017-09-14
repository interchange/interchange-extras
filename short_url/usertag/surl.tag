UserTag surl Order url
UserTag surl addAttr
UserTag surl Routine <<EOA
sub {
	my ($url,$opt) = @_;

	use vars qw/$Tag/;
	my ($log, $die, $warn) = $Tag->logger($opt->{logname} || 'surl', $opt->{logfile} || 'logs/surl.log');

$log->("surl.tag called with path=$url");

	my $db = Vend::Util::dbref('surl')
		or die "No surl database?";

	if($url !~ m{/}) {
		$url = Vend::Util::unhexify($url);
	}

	my $code;

	my $random_chars = "ABCDEFGHJKLMNPQRSTUVWXYZ1234567890";

# Return a string of random characters.

	my $rand = sub {
		my ($len) = @_;
		$len = 6 unless $len;
		my ($r, $i);

		$r = '';
		for ($i = 0;  $i < $len;  ++$i) {
			$r .= substr($random_chars, int(rand(length($random_chars))), 1);
		}
		$r;
	};

	my $len = $opt->{length};
	$len += 0;
	$len ||= 5;

	$code = $rand->($len);
$log->("surl.tag generated code=$code for path=$url");
	$code = $rand->($len)
		while $db->record_exists($code);

	my $record = {
		url => $url,
		ipaddr => $CGI::remote_addr,
		created => POSIX::strftime('%Y%m%d%H%M%S', localtime() ),
	};

$log->("surl.tag generated code=$code for path=$url");

	$db->set_slice($code, $record)
		or return $die->("Unable to set slice for $code: " . $db->errstr());

	my $server = $opt->{server} || $::Variable->{SERVER_NAME};
	return "http://$server/$code";
}
EOA
