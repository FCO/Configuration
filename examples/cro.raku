use Cro::HTTP::Router;
use Cro::HTTP::Server;

use Configuration;

my $application = route {
    get -> 'greet', $name {
        content 'text/plain', "Hello, $name!";
    }
}

class ServerConfig {
    has Str $.host = 'localhost';
    has Int $.port = 80;
}

my Cro::Service $server;
react {
    whenever config-run(ServerConfig, :file<examples/cro.rakuconfig>, :watch) -> $config {
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
