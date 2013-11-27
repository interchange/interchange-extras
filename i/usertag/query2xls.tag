# Copyright 2009 Perusion <mikeh@perusion.com>
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: query2xls.tag,v 1.0 2009-10-12 22:02:57 mheins Exp $

UserTag query2xls AddAttr
UserTag query2xls Version  $Revision: 1.00 $
UserTag query2xls Documentation <<EOD
=head1 NAME

query2xls -- Create XLS spreadsheet files from a SQL query

=head1 SYNOPSIS

   [query2xls 
   		query="select field1,field2,field3 from table1"
		sheet-name="Sheet 1 of 1"
		file-name="file-to-create.xls" 
		base="tablename"
		deliver=1
		width=NN
		max-width=NNN
	]

or 

   [query2xls 
   		query.sheetname1="select * from table1"
   		query.sheetname2="select * from table2"
   		query.sheetname3="select * from table3"
		file-name="file-to-create.xls" 
		base.sheetname2=table2
		width=NN
		deliver=1
		max-width=NNN
	]

or 

   [query2xls 
   		query.0="select * from table1"
   		query.1="select * from table2"
   		query.1="select * from table3"
		file-name="file-to-create.xls" 
		base.1=table2
		width=NN
		deliver=1
		image.0=picture
		image-dir=/var/www/html/images
		max-width=NNN
	]

=head1 DESCRIPTION

The [query2xls] tag accepts one or more SQL queries and outputs an XLS spreadsheet
using the perl Spreadsheet::WriteExcel.

Output is the contents of the file created unless the C<hide> parameter is set.
If there is an error during creation, undef will be returned and the error will
be logged and set in the error array.

You can set the display width of the columns, and also (to some extent) the max string size
allowed.

If you set the C<deliver> parameter, the file will be delivered as
binary content vi the browser. Mime type can be specified in the
C<type>, parameter. The default is I<application/vnd.ms-excel>.

=head2 OPTIONS

=over 4

=item query

Contains the query or queries. Uses standard Interchange array and hash
setting if desired. The sheet name will be the name of the hash member --
if you want capitalization and spaces in the sheet title you should
format and pass a hash like:

    [query2xls query=`{
                    "Basic sheet" => "select sku,description as title,price,image from products",
                    "Full sheet"  => "select * from inventory",
                    "Partial Sheet" => "select * from products where price > 10",
                }`
		 deliver=1 width=20]

Will honor "as" if header columns are to be set.

descending-brightness colors. The default value will cause
the selected tab to have a color of #eeeeee, the first unselected
tab will have #dddddd, the next #cccccc, etc. To create a yellow
series, use #ffffxx.

=item deliver

Set to 1 if the spreadsheet is to be delivered as binary download.

=item base

The base table to find the table specified in the query. Can match the
array and hash status of the C<query> object to mix tables.

=item hide

Standard ITL parameter to prevent output. Normally the tag outputs the
binary spreadsheet suitable for writing to a file.

=item file-name

The name of the file to be written. Defaults to 

	tmp/xls/SID/spreadsheet.xls

where C<tmp> is the catalog ScratchDir and C<SID> is the session id.

=item save

Set to 1 or the file will be unlinked.

=item image

The name of a field to load an image into. Uses the image-dir attribute
to determine base directory (if any).

=item panel_width

=back

=head1 AUTHOR

Mike Heins, <mikeh@perusion.com>.

=head1 BUGS

The usual number.

=cut
EOD

UserTag query2xls Routine  <<EOR
sub {
	my $opt = shift;
	my $query = $opt->{query} || $opt->{sql};
	my $name = $opt->{file_name} || 'spreadsheet.xls';

	use vars qw/$Tag/;
	my $pf0 = $Vend::Cfg->{ProductFiles}[0];

	my %query;
	my %base;
	if(! ref $query) {
#::logDebug("Think query is a scalar");
		my $q = $query;
		undef $query;
		$q =~ s/\s+$//;
		$q =~ s/^\s+//;
		$opt->{sheet_name} ||= 'Sheet 1';
		$query{$opt->{sheet_name}} = $q;
		$base{$opt->{sheet_name}} = $opt->{base} || $pf0;
	}

	if(ref $opt->{base} eq 'HASH') {
		%base = %{$opt->{base}};
	}
	elsif(ref $opt->{base} eq 'ARRAY') {
		my $i = 0;
		for(@{$opt->{base}}) {
			$base{$i++} = $_;
		}
	}
	
	my $set = $opt->{set} || {};

	if(ref $set ne 'HASH') {
		$set = get_option_hash($set);
	}

	my @order;

	if(ref $query eq 'HASH' ) {
#::logDebug("Think query is a hash, of: " . ::uneval($query));
		for (sort keys %$query) {
			my $k = $_;
			my $v = $query->{$k};
#::logDebug("processing query $k=$v");
			$query{$k} = $v;
			push @order, $k;
			$base{$k} = $base{$k} || $opt->{base} || $pf0;
		}
	}
	elsif(ref $query eq 'ARRAY') {
		my $base_sheet;
		if(ref $opt->{sheet_name} eq 'ARRAY') {
			@order = @{$opt->{sheet_name}};
		}
		else {
			$base_sheet = $opt->{sheet_name} || 'Sheet ';
		}
		my $i = 0;
		for(@{$query}) {
			my $sn = $order[$i];
			$i++;
			if($base_sheet) {
				$sn = $base_sheet . $i;
			}
			$query{$sn} = $_;
			$base{$sn} = $base{$sn} || $base{$i - 1} || $opt->{base} || $pf0;
		}
	}

	my %image;
	my $image = $opt->{image};
	if(ref $image eq 'HASH' ) {
#::logDebug("Think image is a hash, of: " . ::uneval($image));
		for (sort keys %$image) {
			my $k = $_;
			my $v = $image->{$k};
#::logDebug("processing image $k=$v");
			$image{$k} = $v;
			push @order, $k;
			$base{$k} = $base{$k} || $opt->{base} || $pf0;
		}
	}
	elsif(ref $image eq 'ARRAY') {
		my $base_sheet;
		if(ref $opt->{sheet_name} eq 'ARRAY') {
			@order = @{$opt->{sheet_name}};
		}
		else {
			$base_sheet = $opt->{sheet_name} || 'Sheet ';
		}
		my $i = 0;
		for(@{$image}) {
			my $sn = $order[$i];
			$i++;
			if($base_sheet) {
				$sn = $base_sheet . $i;
			}
			$image{$sn} = $_;
			$base{$sn} = $base{$sn} || $base{$i - 1} || $opt->{base} || $pf0;
		}
	}


#::logDebug("created image hash: " . ::uneval(\%image));

	use vars qw/$Tag/;
	my $dir = "$Vend::Cfg->{ScratchDir}/xls/$Vend::Session->{id}";
	$name = "$dir/$name";
	use File::Path;
	use Spreadsheet::WriteExcel;

	File::Path::mkpath($dir) unless -d $dir;

	my $Max_xls_string = 255;

	my $die = sub {
		my $msg = errmsg(@_);
		$Tag->error({ name => 'query2xls', set => $msg });
		::logError("query2xls: $msg");
		return undef;
	};

	my $xls = Spreadsheet::WriteExcel->new($name)
		or return $die->("Unable to create spreadsheet %s", $name);

	if($opt->{max_xls_string}) {
		$Max_xls_string = int($opt->{max_xls_string}) || 255;
		$xls->{_xls_strmax} = $Max_xls_string;
	}

	my $width = $opt->{width};
	$width = get_option_hash($width) unless ref $width eq 'HASH';

	my $numeric = $opt->{numeric};
	$numeric = get_option_hash($numeric) unless ref $numeric eq 'HASH';

	my $filter = $opt->{filter};
	$filter = get_option_hash($filter) unless ref $filter eq 'HASH';

	my @errors;

	my %format;

	for my $col (keys %$set) {
		my $opts = $set->{$_};
		my @sets;
		if(ref $opts eq 'ARRAY') {
			for my $o (@$opts) {
				push @sets, $o;
			}
		}
		else {
			my @opts = Text::ParseWords::shellwords($opts);
			for(@opts) {
				push @sets, [ split /\|/, $_ ];
			}
		}

		my $form = $xls->add_format();
		for my $ary (@sets) {
			my $method = shift @$ary;
			eval {
				$form->$method(@$ary);
			};
			if($@) {
				$die->("format method $method failed with args " . uneval($ary));
			}
		}
		$format{$col} = $form;
	}

#::logDebug("formats are: " . ::uneval(\%format));

	my $h = 0;
    for(sort keys %query) {
		my $sn   = $_;
		my $q    = $query{$_};
#::logDebug("creating sheet: " . $sn);
		my $sheet = $xls->addworksheet($sn)
			or return $die->("Unable to create sheet '%s'", $sn);
#::logDebug("created sheet object: " . $sheet);
		my $tab = $base{$sn} || $opt->{base} || $pf0;
#::logDebug("referencing table: " . $tab);
		my $db = dbref($tab);
		$sheet->{_xls_strmax} = $Max_xls_string
			if defined $opt->{max_xls_string};
		
		my ($ary, $fn, $fa) = $db->query($q);

		if(! $ary) {
			my $err = $db->errstr;
			return $die->("%s query failed: %s\nerror: %s", 'query2xls', $q, $err);
		}

		my $image = $image{$sn} || $opt->{image};
		my $iidx;
	  
#::logDebug("creating header line: " . ::uneval(\@$fa));

		for(my $j = 0; $j <= @$fa; $j++) {
			if(my $w = $width->{$fa->[$j]}) {
#::logDebug("Setting column $j ($fa->[$j]) width to $w");
				$sheet->set_column($j, $j, $w);
			}
			if($fa->[$j] eq $image) {
				$iidx = $j;
			}
			$sheet->write_string(0, $j, $fa->[$j])
				if length $fa->[$j];
		}
  
		my $i = 1;
		for my $f (@$ary) {
			chomp;
#::logDebug("writing row $i: " . ::uneval(\@$f));
			for(my $j = 0; $j < @$f; $j++) {
				if($iidx and $j == $iidx and $f->[$j] and $f->[$j] !~ /^http:/) {
					$sheet->set_row(0, undef, 20);
					my $fn = $opt->{image_dir} || '';
					$fn and $fn =~ s{/*$}{/};
					$f->[$j] =~ s{^/*}{};
					$fn = "$fn$f->[$j]";
#::logDebug("creating image for row $i, col $j: $fn");
#::logDebug("file size for $fn: " . -s $fn);
					my $status = $sheet->insert_image($i, $j, $fn);
					#my $status = $sheet->insert_image("L3", $fn);
#::logDebug("Status for insert_image: " . ::uneval($status));
				}
				else {
					if(my $filt = $filter->{$fa->[$j]}) {
						$f->[$j] = filter_value($filt, $f->[$j]);
					}
					if(length $f->[$j]) {
						if($numeric->{$fa->[$j]}) {
							$sheet->write_number($i, $j, $f->[$j], $format{$fa->[$j]});
						}
						else {
							$sheet->write_string($i, $j, $f->[$j], $format{$fa->[$j]});
						}
					}
				}
			}
			$i++;
		}
  	
		$h++;
#::logDebug("finished sheet $sn");
#::logDebug("file size for $name: " . -s $name);
    }

	undef $xls;
#::logDebug("file size for $name: " . -s $name);
	my $out = $Tag->file($name);
	unlink $name unless $opt->{save};
	if($opt->{deliver}) {
		my $pg = $Global::Variable->{MV_PAGE};
		$opt->{extra_headers} ||= qq{Content-Disposition: inline; filename="$opt->{file_name}"};
		$opt->{type} ||= 'application/vnd.ms-excel';
		$Tag->deliver({ extra_headers => $opt->{extra_headers}, type => $opt->{type}, body => $out });
		return length($out);
	}
	return $out;
}
EOR
