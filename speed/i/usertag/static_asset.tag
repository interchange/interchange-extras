Usertag static-asset Order file
Usertag static-asset Interpolate
UserTag static-asset Routine <<EOR
use File::Basename;
sub {
    my $filename = shift;
    return $filename if $filename =~ /^http/;

    my $docroot = $::Variable->{DOCROOT};
    my $file    = $docroot . '/' . $filename;

    my $mtime = (stat $file)[9]
        or return $filename;

    my ( $name, $dirs, $ext ) = fileparse( $filename, qr/\.[^.]*/ )
        or return $filename;

    return join '', $dirs, $name, '.', $mtime, $ext;
}
EOR
