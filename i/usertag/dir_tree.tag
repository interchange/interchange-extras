UserTag dir_tree Order        dir sort exclude dir_mask
UserTag dir_tree hasEndTag
UserTag dir_tree AddAttr
UserTag dir_tree Description  Show files from a directory (traverses down). Exclude is a regex.
UserTag dir_tree Routine      <<EOR
sub {
		my ($dir, $sort, $exclude, $dir_mask, $opt, $list) = @_;

		return unless $dir;

		my $docroot = $::Variable->{DOCROOT};
		my $fullpath = $docroot . '/' . $dir;

#::logDebug("dir_tree: fullpath= $fullpath");

		my @files;

		require File::Find;
		my $wanted;

		$wanted = sub {
			return if $exclude && $_ =~ /$exclude/i;
			push (@files, $File::Find::name);
		};
		File::Find::find($wanted, $fullpath);

		s:^./:: for @files;
		s:^$docroot:: for @files;
		@files = grep {/\..{1,4}/} @files;   # omit just directory entries

#return ::uneval(\@files);

		my @items;

		for (@files) {
			my ($elif, $htap) = split(/\//, (reverse $_), 2);
			my $ref;
			$ref->{code} = $_;   # full path
			$ref->{path} = reverse $htap;
			$ref->{file} = reverse $elif;
			push @items, $ref;
		}

#return ::uneval(\@items);

		if($opt->{sort} eq 'r') {
			## sort by path (reverse), then by filename, as strings
			@items = sort { $b->{path} cmp $a->{path} || $a->{code} cmp $b->{code} } @items;
		}
		elsif($opt->{sort} eq 'n') {
			## sort by path, then by filename, as numbers
			@items = sort { $a->{path} <=> $b->{path} || $a->{code} <=> $b->{code} } @items;
		}
		else {
			## sort by path, then by filename, as strings
			@items = sort { $a->{path} cmp $b->{path} || $a->{code} cmp $b->{code} } @items;
		}

		$opt->{prefix} ||= 'dir';

		my $object = {
			prefix => $opt->{prefix},
			mv_results => \@items,
		};
		$opt->{object} = $object;
		region( $opt, $list );
}
EOR
UserTag dir_tree Documentation <<EOD

Example:
    [table-organize
        table='cellspacing=0 class=newsletters'
        cols=2
        td='style="vertical-align:top"'
    ]
        [dir-tree dir="newsletters" exclude="\.(htaccess|log)$" sort=r]
            [dir-change path][condition][dir-param path][/condition]
                [dir-alternate except_first]
                    </div>
                    </td>
                [/dir-alternate]
                <td>
                    <h4>[dir-param path]</h4>
                    <div>
            [/dir-change path]
            <a href="[dir-code]" target="newsletter">[dir-param file]</a><br>
        [/dir-tree]
    </td>
    </div>
    [/table-organize]
EOD
