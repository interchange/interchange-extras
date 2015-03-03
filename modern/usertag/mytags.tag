Require module Vend::MyModule
UserTag my-session-value Order session key
UserTag my-session-value Routine <<EOR
sub {
	use Vend::MyModule;
	my $session = shift;
	my $key = shift;
	my $m = Vend::MyModule->new();
	return $m->my_session_value( $session, $key );
}
EOR
