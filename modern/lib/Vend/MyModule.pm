package Vend::MyModule;

use Modern::Perl '2010';

use Vend::Interpolate;

BEGIN {
	if (! $Vend::Cfg->{Database}) {
		use Carp;
		require DBI;
	}
}

sub new {
	my $class = shift;
	my $args = shift || {};
	my $self = { %$args };
	return bless $self, $class;
}

sub log {
	my $self = shift;
	my $fmt = shift;
	my $msg = sprintf($fmt, @_);
	if ($Vend::Cfg->{Database}) {
		::logError($msg, { file => $self->{logfile} });
	}
	else {
		carp $msg;
	}
	return;
}

sub die {
	my $self = shift;
	my $fmt = shift;
	my $msg = sprintf($fmt, @_);
	if ($Vend::Cfg->{Database}) {
		Vend::Tags->error({ name => $self->{error_name}, set => $msg });
		::logError('died: ' . $msg, { file => $self->{logfile} });
	}
	else {
		croak $msg;
	}
	return;
}

sub warn {
	my $self = shift;
	my $fmt = shift;
	my $msg = sprintf($fmt, @_);
	if ($Vend::Cfg->{Database}) {
		Vend::Tags->warnings($msg);
		::logError($msg, { file => $self->{logfile} });
	}
	else {
		carp "warn: $msg";
	}
	return;
}

sub _is_username {
	## sample private function
	my $self = shift;
	my $username = shift;
	return unless $username;
	my $uq = q{
		SELECT 1
		FROM userdb
		WHERE username = ?
	};
	my $usth = $self->dbh('userdb')->prepare($uq);
	$usth->execute( $username );
	my $is_username = ($usth->fetchrow_array())[0] || 0;
	return $is_username;
}

sub my_session_value {
	## sample public function
	my $self = shift;
	my ($sid,$key) = @_;
	my $fn = Vend::File::get_filename($sid,2,1,'session');
	my @sess = grep $_ !~ /\.lock$/, glob("$fn*")
		or return;

	## Might add some error checking in case of multiple file return (though it is unlikely)
	my $sfn = $sess[0];

	my $session = Vend::Util::eval_file($sfn);

	$key ||= 'values.email';
	my (@levels) = split /\./, $key;

	my $val = $session;
	while (my $next = shift @levels) {
		eval {
			$val = $val->{$next};
		};
		if($@) {
			$self->die("session-value: Bad session key '%s'", $key);
		}
	}
	return $val;
}

sub dbh {
	my $self = shift;
	my $tab = shift;
	if ( $self->{_tables}{$tab} ) {
		return $self->{_tables}{$tab};
	}
	elsif ($Vend::Cfg->{Database}) {
		my $dbref = Vend::Data::dbref($tab)
			or $self->die("No table $tab");
		$self->{_tables}{$tab} = $dbref->dbh();
	}
	else {
		my $dbh = DBI->connect( $Vend::Cfg->{Variable}->{SQLDSN}, $Vend::Cfg->{Variable}->{SQLUSER}, $Vend::Cfg->{Variable}->{SQLPASS} )
			or $self->die("No table $tab at $Vend::Cfg->{Variable}->{SQLDSN}");
		$self->{_tables}{$tab} = $dbh;
	}
}

1;
