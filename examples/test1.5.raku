use Configuration;

class DBConfig {
    has Str $.host = 'localhost';
    has Int $.port = 5432;
    has Str $.dbname;
}

class Test1Config {
    has Int $.a;
    has Int $.b = $!a * 2;
    has Int $.c = $!b * 3;
    has DBConfig $.db .= new;
}

say await config-run(Test1Config, :file<examples/test1.rakuconfig>)
