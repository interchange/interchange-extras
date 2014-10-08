UserTag yt-list Order        playlist
UserTag yt-list hasEndTag
UserTag yt-list AddAttr
UserTag yt-list Description  Process a video playlist feed from YouTube.
UserTag yt-list Routine      <<EOR
require JSON;
require LWP::UserAgent;
sub {
	my ($playlist, $opt, $list) = @_;
	my $key = $::Variable->{YOUTUBE_DEVELOPER_KEY};

	my $base_uri = 'http://gdata.youtube.com/feeds/api/playlists/';
	my $parms = "?v=2&alt=jsonc&key=$key&max-results=50";
	my $url = $base_uri . $playlist . $parms;

	my $raw_feed = new LWP::UserAgent->get($url)->content;

	my $json = JSON->new->latin1;
	my $json_feed = $json->decode( $raw_feed );

	my @items;

	my $basic = $json_feed->{data};

	for my $tmp (@{$basic->{items}}) {
		my $it = $tmp->{video};
		my $ref = { object => { %$it } };
		for( qw/ 
				content
				title
				description
				id
				duration
				location
				rating
				viewCount
				uploaded
			/)
		{
			$ref->{lc $_} = $it->{$_};
		}
		$ref->{thumbnail_hq} = $it->{thumbnail}{hqDefault};
		$ref->{thumbnail} = $it->{thumbnail}{sqDefault};
		$ref->{mobile_player} = $it->{player}->{mobile};
		$ref->{player} = $it->{player}->{default};
		push @items, $ref;
	}

	$opt->{prefix} ||= 'yt';

	my $object = { 
		prefix => $opt->{prefix},
		mv_results => \@items,
	};

	$opt->{object} = $object;
	region( $opt, $list );
}
EOR
