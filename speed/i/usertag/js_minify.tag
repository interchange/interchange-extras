UserTag js-minify hasEndTag
UserTag js-minify AddAttr

UserTag js-minify Documentation <<EOD

Documentation for the js-minify usertag.

Uses Google's Closure Compiler Service to minify Javascript.

NOTES:

	If you change your javascript, you should always test to make sure the Compiler
	can parse it.

	You should always surround this tag with [timed-build], unless you are 
	developing.

	You can pass interpolate=1 if your Javascript has IC tags, but this may 
	negate the use of [timed-build], unless the IC always evaluates the same.
	And if you don't use [timed-build], you shouldn't use this usertag...

ATTRIBUTES:
For details, see: http://code.google.com/closure/compiler/docs/api-ref.html

	show_stats:
		set to 1 to show before/after statistics and timestamp in a comment above
		your javascript.

	level:
		WHITESPACE_ONLY, SIMPLE_OPTIMIZATIONS (default), ADVANCED_OPTIMIZATIONS

	output:
		compiled_code (default), warnings, errors, statistics
		-- use output=errors if you get nothing with normal usage.

TODO:
	Implement 'code_url' parameter, so you can pass a file for compilation.
	Or else create a command-line script, that saves the output in a file
	named with the MD5 of the original file. 

EOD

UserTag js-minify Routine      <<EOR
require LWP::UserAgent;

sub {
	my ($opt, $body) = @_;

	my $compiler = 'http://closure-compiler.appspot.com/compile';
	my $ua = LWP::UserAgent->new;
	$ua->timeout(45);

	my %args;
	$args{js_code} = $body;
	$args{compilation_level} = $opt->{level}         || 'SIMPLE_OPTIMIZATIONS';
	$args{output_info}       = $opt->{output}        || 'compiled_code';
	$args{output_format}     = $opt->{output_format} || 'text';

	my $response = $ua->post($compiler, \%args);
	#return ::uneval(%$response);  # for testing

	my $out;
	$out = $response->content if ($response->is_success);

	if($opt->{show_stats} && $out) {
		$args{output_info} = 'statistics';
		$args{output_format} = 'text';
		my $stats_resp = $ua->post($compiler, \%args);
		if($stats_resp->is_success) {
			my $stats = 'built at: ' . strftime('%c',localtime) . "\n";
			$stats .= $stats_resp->content;
			chomp($stats);
			$stats =~ s|\n|\n// |g;
			$out = "\n// " . $stats . "\n" . $out;
		}
	}

	return $out ? $out : $body;
}
EOR
