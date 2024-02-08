use v6.d;
use Cro::HTTP::Server;

my $old;
class ServerConfig {
    has Str $.host = 'localhost';
    has Int $.port = 80;
    has     $.server is rw;

    method create-server($application) {
        $!server = Cro::HTTP::Server.new: :$!host, :$!port, :$application;
        $!server.start;
        say "server started on { $!host }:{ $!port }";
        .stop with $old;
        $old = $!server;
    }

    method stop-server {
        $!server.stop
    }
}
use Configuration ServerConfig;
