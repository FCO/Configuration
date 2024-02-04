Very early stage of development!

Example
=======

For defining what classes to use as configuration, you can do something like:

Configuration definition (Test1Config.pm)
-----------------------------------------

```raku
use v6.d;
use Configuration;

class RootConfig does Configuration::Node {
    has Int      $.a;
    has Int      $.b      = $!a * 2;
    has Int      $.c      = $!b * 3;
}

sub EXPORT {
    generate-exports RootConfig
}
```

Then, for using that to write a configuration, it's just question of:

Configuration (`my-conf.rakuconfig`)
------------------------------------

```raku
use Test1Config;

config {
    .a = 1;
    .c = 42;
}
```

It uses the `config` function exported by the module created before that waits for a block that will expect a builder for the configured class as the first parameter.

Program using the configuration:
--------------------------------

```raku
use Test1Config;

say await config-run :file<examples/test1.rakuconfig>
```

On your software you will use the same module where you defined the configuration, and use it's exported functions to the the populated configuration class object.

This, with that configuration, will print:

```raku
Test1Config.new(a => 1, b => 2, c => 42)
```

But you could also make it reload if the file changes:

```raku
use Test1Config;

react whenever config-run :file<./my-conf.rakuconfig>, :signal(SIGUSR1) {
    say "Configuration changed: { .raku }";
}
```

The whenever will be called every time the configuration change and SIGUSR1 is sent to the process. It also can watch the configuration file:

```raku
use Test1Config;

react whenever config-run :file<./my-conf.rakuconfig>, :watch {
    say "Configuration changed: { .raku }";
}
```

And it will reload whenever the file changes. The `whenever`, with the current configuration, will receive this object:

```raku
Test1Config.new(a => 1, b => 2, c => 42)
```

If your config declaration changed to something like this:

```raku
use Configuration;

class DBConfig does Configuration::Node {
    has Str $.host = 'localhost';
    has Int $.port = 5432;
    has Str $.dbname;
}

class RootConfig does Configuration::Node {
    has Int $.a;
    has Int $.b = $!a * 2;
    has Int $.c = $!b * 3;
    has DBConfig $.db .= new;
}

sub EXPORT {
    generate-exports RootConfig
}
```

Your `whenever` will receive an object like this:

```raku
RootConfig.new(a => 1, b => 2, c => 42, db => DBConfig.new(host => "localhost", port => 5432, dbname => Str))
```

And if you want to change your configuration to populate the DB config, you can do that with something like this:

```raku
config {
    .a = 1;
    .c = 42;
    .db: {
        .dbname = "my-database";
    }
}
```

And it will generate the object:

```raku
Test1Config.new(a => 1, b => 2, c => 42, db => DBConfig.new(host => "localhost", port => 5432, dbname => "my-database"))
```

An example with Cro could look like this:

Config Declaration (ServerConfig.rakumod):
------------------------------------------

```raku
use v6.d;
use Configuration;
use Cro::HTTP::Server;

my $old;
class ServerConfig does Configuration::Node {
    has Str $.host = 'localhost';
    has Int $.port = 80;
    has     $.server is rw;

    method create-server($application) {
        $!server = Cro::HTTP::Server.new: :$.host, :$.port, :$application;
        $!server.start;
        say "server started on { $!host }:{ $!port }";
        .stop with $old;
        $old = $!server;
    }

    method stop-server {
        $!server.stop
    }
}

sub EXPORT {
    generate-exports ServerConfig;
}
```

And the code could look something like this:

```raku
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
            $config.stop-server;
            done;
        }
    }
}
```

