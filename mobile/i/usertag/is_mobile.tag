UserTag is_mobile hasEndTag
UserTag is_mobile Order reverse
UserTag is_mobile Routine <<EOR
use HTTP::BrowserDetect;
sub {
	my $rev = shift;
	if(! defined $Vend::Session->{phone_browser}) {
		my $ua = HTTP::BrowserDetect->new($Vend::Session->{browser});
		if ($ua->tablet()) {
			$Vend::Session->{phone_browser} = 0;
		}
		elsif ($ua->mobile()) {
			 $Vend::Session->{phone_browser} = 1;
		}
		else {
			 $Vend::Session->{phone_browser} = 0;
		}
	}

	my $truth = $Vend::Session->{phone_browser};
	$rev and $truth = ! $truth;
	
	return $truth ? Vend::Interpolate::pull_if(shift (@_))  : Vend::Interpolate::pull_else(shift (@_) );
}
EOR

UserTag handle_mobile Routine <<EOR
use HTTP::BrowserDetect;
sub {
	##
	## use ?gomo=1 to force mobile (even if not a mobile browser)
	## use ?nomo=1 to force desktop
	##
	if($CGI->{gomo}) {
		delete $Vend::Session->{nomo};
		$Vend::Session->{phone_browser} = 1;
	}
	else {
		$Vend::Session->{nomo} ||= $CGI->{nomo};
		return if $Vend::Session->{nomo} == 1;
	}

	if(! defined $Vend::Session->{phone_browser}) {
		my $ua = HTTP::BrowserDetect->new($Vend::Session->{browser});
		if ($ua->tablet()) {
			$Vend::Session->{phone_browser} = 0;
		}
		elsif ($ua->mobile()) {
			$Vend::Session->{phone_browser} = 1;
		}
		else {
			$Vend::Session->{phone_browser} = 0;
		}
	}
	return unless $Vend::Session->{phone_browser};

	## send to m/ pages or do display_class
	my ($fp, $path, $mpath);
	$fp = $path = $mpath = $Vend::FinalPath;
	return if $fp =~ m:^/m(/.*)?$:;
#::logDebug("FinalPath is: " . $fp);

	if(!$fp) {
		$Vend::FinalPath = '/m';
		return;
	}

	$path = $Vend::Cfg->{VendRoot} . '/pages' . $path;
	$mpath = $Vend::Cfg->{VendRoot} . '/pages/m' . $mpath;
	for($path, $mpath) {
		s:(/|index/?)$:/index:;
		s:(?!\.html)$:.html:;
	}
#::logDebug("path is: " . $path);

	if(-f $mpath) {
#::logDebug("found mobile page; path is: " . $mpath);
		$Vend::FinalPath = '/m' . $fp;
	}
	elsif(-f $path) {
#::logDebug("found regular page; path is: " . $path);
		$::Scratch->{display_class} = 'mobile';
	}
	else {  # flypage, results, or ?
#::logDebug("found special page");
		## send to 'm/flypage', if a sku in products
		my $sku = dbref($Vend::Cfg->{ProductFiles}[0])->record_exists(substr($fp, 1));
		$Vend::ForceFlypage = 'm/flypage' if $sku;
		## if not a sku, then do default, but somehow set results page
		$CGI->{mresults} = 'm/results';
		$::Scratch->{display_class} = 'mobile';
	}

	return;
}
EOR
