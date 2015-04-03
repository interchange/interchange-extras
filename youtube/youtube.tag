UserTag youtube-pl-feed Order        playlist part
UserTag youtube-pl-feed AddAttr
UserTag youtube-pl-feed Description  Displays the perl structure of a YouTube playlistItems feed.
UserTag youtube-pl-feed Routine      <<EOR
require JSON;
require LWP::UserAgent;
sub {
	my ($playlist, $part, $opt) = @_;
	return die "need playlist" unless $playlist;

	my $key = $::Variable->{YOUTUBE_DEVELOPER_KEY}
		or die "need developer key";
	my $base_uri = 'https://www.googleapis.com/youtube/v3/playlistItems';

	$part ||= 'snippet';
	my $parms = "?part=$part&playlistId=$playlist&key=$key&maxResults=50";
	my $url = $base_uri . $parms;
#::logDebug($url);

	my $raw_feed = new LWP::UserAgent->get($url)->content;

	my $json = JSON->new->latin1;
	my $json_feed = $json->decode( $raw_feed );

	return ::uneval($json_feed);
}
EOR

UserTag yt-playlistitems Order        playlist part
UserTag yt-playlistitems AddAttr
UserTag yt-playlistitems Description  List playlist items from Youtube, to be used with yt-videos tag
UserTag yt-playlistitems Routine      <<EOR
require JSON;
require LWP::UserAgent;
sub {
	my ($playlist, $part, $opt, $list) = @_;
	return die "need playlist" unless $playlist;

	my $key = $::Variable->{YOUTUBE_DEVELOPER_KEY}
		or die "need developer key";
	my $base_uri = 'https://www.googleapis.com/youtube/v3/playlistItems';

	$part ||= 'snippet';
	my $parms = "?part=$part&playlistId=$playlist&key=$key&maxResults=50";
	my $url = $base_uri . $parms;

	my $raw_feed = new LWP::UserAgent->get($url)->content;

	my $json = JSON->new->latin1;
	my $json_feed = $json->decode( $raw_feed );

	my @items;
	for my $tmp (@{$json_feed->{items}}) {
		push @items, $tmp->{snippet}{resourceId}{videoId};
	}
	return join ',',@items;
}
EOR

UserTag yt-videos Order          part id
UserTag yt-videos hasEndTag
UserTag yt-videos AddAttr
UserTag yt-videos Description    Process a video list from YouTube.
UserTag yt-videos Documentation  <<EOD

	part is fields you want.
	id is comma-separated list of YT video ids.

	https://developers.google.com/youtube/v3/docs/videos/list

	Go here to get a key:
	https://console.developers.google.com/project

EOD
UserTag yt-videos Routine      <<EOR
require JSON;
require LWP::UserAgent;
sub {
	my ($part, $id, $opt, $list) = @_;
	return die "need id" unless $id;

	my $key = $::Variable->{YOUTUBE_DEVELOPER_KEY}
		or die "need developer key";
	my $base_uri = 'https://www.googleapis.com/youtube/v3/videos';

	$part ||= 'snippet';
	my @ids = split /[\s,\0]+/, $id;
	for(@ids) {
		s/^v=//;
	}
	my $ids = join ',',@ids;

	my $parms = "?part=$part&id=$ids&key=$key";
	my $url = $base_uri . $parms;

	my $raw_feed = new LWP::UserAgent->get($url)->content;
#return $raw_feed;

	my $json = JSON->new->latin1;
	my $json_feed = $json->decode( $raw_feed );
return $Tag->uneval({ ref => $json_feed }) if $opt->{output} eq 'raw';

	my @items;
	for my $tmp (@{$json_feed->{items}}) {
		my $snip = $tmp->{snippet};
		my $ref = {};
		for (qw/ title description /) {
			$ref->{$_} = $snip->{$_};
		}
		$ref->{code} = $tmp->{id};
		$ref->{thumbnail} = $snip->{thumbnails}{default}{url};
		$ref->{thumbnail_medium} = $snip->{thumbnails}{medium}{url};
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
