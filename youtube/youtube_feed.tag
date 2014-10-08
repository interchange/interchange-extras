UserTag youtube-feed Order        playlist
UserTag youtube-feed AddAttr
UserTag youtube-feed Description  Displays the perl structure of a YouTube feed. For testing.
UserTag youtube-feed Routine      <<EOR
require JSON;
require LWP::UserAgent;
sub {
	my ($playlist, $opt) = @_;
	my $key = $::Variable->{YOUTUBE_DEVELOPER_KEY};

	my $base_uri = 'http://gdata.youtube.com/feeds/api/playlists/';
	my $parms = "?v=2&alt=jsonc&key=$key&max-results=50";
	my $url = $base_uri . $playlist . $parms;

	my $raw_feed = new LWP::UserAgent->get($url)->content;

	my $json = JSON->new->latin1;
	my $json_feed = $json->decode( $raw_feed );

	return ::uneval($json_feed);
}
EOR
