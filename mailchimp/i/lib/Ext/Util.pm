package Ext::Util;

# ABSTRACT: functions for Ext modules

use strict;
use warnings;

use Vend::Interpolate;
use Vend::Util ();
use Carp qw/ carp croak /;

BEGIN {
    require DBI if ! $Vend::Cfg->{Database};
}

sub new {
    my $class = shift;
    my $opt = shift || {};
    my $self = { %$opt };
    $self->{ic_present} = $Vend::Cfg->{Database};
    bless $self, $class;
    return $self;
}

sub log {
    my $self = shift;
    my $fmt = shift or return;
    my $msg = sprintf $fmt, @_;
    $self->{ic_present}
        ? ::logError( $msg, { file => $self->{logfile} } )
        : carp $msg;
}

sub die {
    my $self = shift;
    my $fmt = shift or return;
    my $msg = sprintf $fmt, @_;
    $self->{ic_present} and do {
        Vend::Tags->error({ name => $self->{error_name}, set => $msg });
        ::logError('died: ' . $msg, { file => $self->{logfile} });
        return;
    };
    croak $msg;
}

sub warn {
    my $self = shift;
    my $fmt = shift or return;
    my $msg = sprintf $fmt, @_;
    $self->{ic_present} and do {
        Vend::Tags->warnings($msg);
        ::logError($msg, { file => $self->{logfile} });
        return;
    };
    carp 'warn: ' . $msg;
}

sub dumper {
    my ($self, $opt, $pretty) = @_;
    ! $self->{ic_present} and return Data::Dumper($opt);
    return $pretty ? Vend::Util::uneval($opt) : Vend::Util::uneval_it($opt);
}

sub dbh {
    my ($self, $tab) = @_;
    if ( $self->{_tables}{$tab} ) {
        return $self->{_tables}{$tab};
    }
    elsif ($Vend::Cfg->{Database}) {
        my $dbref = Vend::Data::dbref($tab)
            or $self->die('No table %s', $tab);
        $self->{_tables}{$tab} = $dbref->dbh();
    }
    else {
        my $dbh = DBI->connect(
            $Vend::Cfg->{Variable}->{SQLDSN},
            $Vend::Cfg->{Variable}->{SQLUSER},
            $Vend::Cfg->{Variable}->{SQLPASS},
        ) or $self->die('No table %s at %s', $tab, $Vend::Cfg->{Variable}->{SQLDSN});
        $self->{_tables}{$tab} = $dbh;
    }
}

1;
