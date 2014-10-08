UserTag yt-videos Order          part id
UserTag yt-videos hasEndTag
UserTag yt-videos AddAttr
UserTag yt-videos Description    Process a video list from YouTube.
UserTag yt-videos Documentation  <<EOD

	part is fields you want.
	id is comma-separated list of YT video ids.

	https://developers.google.com/youtube/v3/docs/videos/list

	Go here to get a key:
	http://code.google.com/apis/console

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
#return uneval($json_feed);

	my @items;

	for my $tmp (@{$json_feed->{items}}) {
		my $it = $tmp->{snippet};
		my $ref = { object => { %$it } };
		for( qw/ 
				title
				description
				thumbnails
			/)
		{
			$ref->{lc $_} = $it->{$_};
		}
		$ref->{code} = $tmp->{id};
		$ref->{thumbnail} = $it->{thumbnails}{default}{url};
		$ref->{thumbnail_medium} = $it->{thumbnails}{medium}{url};
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
