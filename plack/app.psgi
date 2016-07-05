use Plack::Builder;
use Plack::App::WrapCGI;

my $ic_root    = '/path/to/interchange';             # path to your interchange server
my $doc_root   = '/path/to/catalogs/strap/html/';    # your website's document root
my $cat_script = '/strap';                           # script_name from the `Catalog` line in interchange.cfg

builder {

    # restart interchange
    my $ic = $ic_root . '/bin/interchange -r';
    print $ic ? $ic . "\n" : "ERROR: failed to restart interchange\n";

    # Static files
    enable 'Static',
      path => qr{^/(images|js|css)/},
      root => $doc_root;

    enable 'ForceEnv' => SCRIPT_NAME => $cat_script;

    # Mount paths
    mount '/' => Plack::App::WrapCGI->new( script => $ic_root . '/src/vlink', execute => 1 )->to_app;

};
