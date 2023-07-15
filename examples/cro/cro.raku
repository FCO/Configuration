use Cro::HTTP::Router;
use Cro::HTTP::Server;

use lib "./examples/cro";
use ServerConfig;

my $application = route {
    get -> 'greet', $name {
        content 'text/plain', "Hello, $name!";
    }
}

my Cro::Service $server;
react {
    whenever config-run :file<examples/cro/cro.rakuconfig>, :watch -> $config {
        my $old = $server;
        $server = Cro::HTTP::Server.new:
                  :host($config.host), :port($config.port), :$application;
        $server.start;
        say "server started on { $config.host }:{ $config.port }";
        .stop with $old;
    }
    whenever signal(SIGINT) {
        $server.stop;
        exit;
    }
}
