use v6.d;
use Configuration;

class ServerConfig does Configuration::Node {
    has Str $.host = 'localhost';
    has Int $.port = 80;
}

sub EXPORT {
    generate-exports ServerConfig;
}