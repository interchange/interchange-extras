UserTag qemail Order to subject reply from extra
UserTag qemail hasEndTag
UserTag qemail addAttr
UserTag qemail Interpolate
UserTag qemail Routine <<EOR
sub {
    return $::Variable->{EMAIL_VIA_MANDRILL}
        ? Vend::Tags->mandrill_email(@_)
        : Vend::Tags->email(@_);
}
EOR
