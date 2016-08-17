# Run Interchange under Plack

This may not be the fastest way to run Interchange, but if you need a
quick-and-dirty local development instance, it can't be beat.

To run this in production, you'll probably want to proxy it with Nginx,
and you should have a startup/shutdown script for `plackup`, perhaps
with [Ubic](https://metacpan.org/pod/Ubic).

## Setup

1. First, you'll need `cpanm` ([cpanminus](http://cpanmin.us)).

2. Then Plack and a few middlewares:

```
cpanm Plack Plack::Builder Plack::App::WrapCGI Plack::Middleware::Static Plack::Middleware::ForceEnv CGI::Emulate::PSGI CGI::Compile Plack::Handler::Starman
```

## Configuration

Copy the [psgi file](app.psgi) to your Interchange root:
`cp app.psgi /path/to/interchange/`
and customize it.

Customize your catalog's `products/variable.txt` or copy
[`products/site.txt`](products/site.txt) to your catalog and adjust the
variables within.

Set `Mall No` in your `interchange.cfg`.

Don't forget to run your `bin/compile_link` to create the "vlink" file:
```
cd /path/to/interchange/
./bin/compile_link
```

## Start

`plackup -s Starman --workers=1 -p 5001 -a /path/to/interchange/app.psgi -D`

## Load

[http://localhost:5001](http://localhost:5001/)

## Extra credit 1: use a ".dev" domain on your local box

Install `dnsmasq` and then run the [`dnsmasq.sh`](dnsmasq.sh) command as root.

Alter `site.txt` to use the ".dev" domain of your choosing (plus port
number), e.g. http://strap.dev:5001

## Extra credit 2: expose your local server to the internet

Install [ngrok](https://ngrok.com/) and run with:
```
ngrok http 5001
```

Alter the server variables in `site.txt` to use the provided hostname,
and restart or reconfigure Interchange.

Share with friends, clients, or coworkers.
