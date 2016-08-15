package Ext::OurTags;

use strict;
use warnings;

use Vend::Interpolate;

# ABSTRACT: functions for our own modules when called outside of $Vend

BEGIN {
    if ($Vend::Cfg->{Database}) {
        use Carp;
    }
    else {
        require DBI;
    }
}

sub new {
    my $class = shift;
    my $opt = shift || {};
    my $self = { %$opt };
    bless $self, $class;
    return $self;
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
        cluck $msg;
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

sub uneval {
    my ($self, $opt, $pretty) = @_;
    return $pretty ? Vend::Util::uneval($opt) : Vend::Util::uneval_it($opt);
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
        my $dbh = DBI->connect(
            $Vend::Cfg->{Variable}->{SQLDSN},
            $Vend::Cfg->{Variable}->{SQLUSER},
            $Vend::Cfg->{Variable}->{SQLPASS},
        ) or $self->die("No table $tab at $Vend::Cfg->{Variable}->{SQLDSN}");
        $self->{_tables}{$tab} = $dbh;
    }
}

1;
