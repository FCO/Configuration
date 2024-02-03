use Cro::HTTP::Router;
use Cro::HTTP::Server;

use lib "./examples/cro";
use ServerConfig;

my $application = route {
    get -> 'greet', $name {
        content 'text/plain', "Hello, $name!";
    }
}

react {
    whenever config-run :file<examples/cro/cro.rakuconfig>, :watch -> $config {
        $config.create-server: $application;
        whenever signal(SIGINT) {
            $config.server.stop;
            done;
        }
    }
}
