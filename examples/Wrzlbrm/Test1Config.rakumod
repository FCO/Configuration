use v6.d;
use Configuration;

class DBConfig does Configuration::Node {
    has Str $.host = 'localhost';
    has Int $.port = 5432;
    has Str $.dbname;
}

class RootConfig does Configuration::Node {
    has Int      $.a;
    has Int      $.b      = $!a * 2;
    has Int      $.c      = $!b * 3;
    has DBConfig $.db    .= new;
    has Int      $.answer = 42;
}

sub EXPORT {
    generate-exports RootConfig
}