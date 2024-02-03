use v6.d;
use Configuration;
use Cro::HTTP::Server;

my $old;
class ServerConfig does Configuration::Node {
    has Str $.host = 'localhost';
    has Int $.port = 80;
    has     $.server is rw;

    method create-server($application) {
        $!server = Cro::HTTP::Server.new: :host($.host), :port($.port), :$application;
        $!server.start;
        say "server started on { $!host }:{ $!port }";
        .stop with $old;
        $old = $!server;
    }
}

sub EXPORT {
    generate-exports ServerConfig;
}
