class Configuration {
  use Configuration::Utils;
  use Configuration::Node;

  has IO()   $.file = self.default-file;
  has        $.watch;
  has Signal $.signal;
  has Any:U  $.root   is required;
  has Any    $.current;
  has Supply $.supply;

  submethod TWEAK(|) {
      $!watch = $!file if $!file && $!watch ~~ Bool && $!watch;
  }

  method default-file {
      for [
        $*PROGRAM-NAME,
        "{ %*ENV<HOME> }/{ $*PROGRAM-NAME.IO.basename }",
        "/etc/{ $*PROGRAM-NAME.IO.basename }",
      ].map: *.IO.extension("rakuconfig") -> IO() $_ {
        .return if :f
      }
      die "Not found any of these files: "
  }

  method supply-list {
      |(
          ( .watch     with $!watch  ),
          ( signal($_) with $!signal ),
      )
  }

  role Generator[::T $builder] {
      method gen($root) {
          # return sub config(&block:(T)) {
          return sub config(&block) { # Should it be typed?
              CATCH {
                  default {
                      note "Error on configuration file: $_";
                  }
              }
              my %*DATA;
              my %*ROOT := %*DATA;
              block $builder, |choose-pars(&block, :root(%*DATA));
              $root.new(|%*DATA.Map);
          }
      }
  }

  method generate-config {
      my $builder = generate-builder-class $!root;
      Generator[$builder].gen($!root)
  }

  method conf-from-file is hidden-from-backtrace {
      CATCH {
          default {
              warn "Error loading file $!file: $_"
          }
      }
      EVALFILE $!file
  }

  method conf-from-string($str) is hidden-from-backtrace {
      CATCH {
          default {
              warn "Error loading configuration: $_"
          }
      }
      use MONKEY-SEE-NO-EVAL;
      EVAL $str;
  }

  multi method single-run(Str $code) is hidden-from-backtrace {
      self.conf-from-string($code)
  }

  multi method single-run is hidden-from-backtrace {
      self.conf-from-file;
  }

  multi method run is hidden-from-backtrace {
      $!supply = Supply.merge(Supply.from-list([True]), |self.supply-list)
        .map({try self.single-run})
        .grep(*.defined)
        .squish
        .do: { $!current = $_ }
  }

  proto single-config-run(Any:U, |) is export is hidden-from-backtrace {*}

  multi single-config-run(Any:U $root, IO() :$file! where *.f) is hidden-from-backtrace {
      ::?CLASS.new(:$root, :$file).single-run
  }

  multi single-config-run(Any:U $root, Str :$code!) is hidden-from-backtrace {
      ::?CLASS.new(:$root).single-run(:$code)
  }

  multi config-run(Any:U $root, |c) is export is hidden-from-backtrace {
      ::?CLASS.new(:$root, |c).run
  }

  sub generate-config(Any:U $root) is export {
      ::?CLASS.new(:$root).generate-config
  }

  multi get-supply($obj) {$obj.supply}
  multi get-supply($obj, &selector) {
      $obj.supply.map(&selector).squish
  }

  method generate-exports(Any:U $root) {
      PROCESS::<$CONFIG-OBJECT> //= ::?CLASS.new(:$root);

      Map.new:
          '&single-config-run' => -> :$file, :$code {
              $*CONFIG-OBJECT.single-run:
                      |($code with $code),
          },
          '&config-run'        => ->
              IO()     :$file where { :e || fail "File $_ does not exist" },
                       :$watch is copy,
              Signal() :$signal
          {
              $watch = $watch
                  ?? $file
                  !! Nil
                  if $watch ~~ Bool;

              $*CONFIG-OBJECT .= clone(
                  |(file   => $_ with $file),
                  |(watch  => $_ with $watch),
                  |(signal => $_ with $signal),
              );
              $*CONFIG-OBJECT.run
          },
          '&config-supply'     => -> &selector? { $*CONFIG-OBJECT.&get-supply: |($_ with &selector) },
          '&get-config'        => { $*CONFIG-OBJECT.current },
          '&config'            => $*CONFIG-OBJECT.generate-config,
          'ConfigClass'        => generate-builder-class($root),
          |get-nodes($root),
      ;
  }
}

sub generate-exports($root) is export {
  Configuration.generate-exports: $root
}

multi EXPORT($node) {
    Map.new:
        "Configuration" => Configuration,
        "Configuration::Node" => Configuration::Node,
        "&EXPORT" => sub export {
            generate-exports $node
        }
}

multi EXPORT {
    Map.new:
        "Configuration" => Configuration,
        "Configuration::Node" => Configuration::Node,
}

=begin pod

[![Build Status](https://github.com/FCO/Configuration/workflows/test/badge.svg)](https://github.com/FCO/Configuration/actions)
[![SparrowCI](https://ci.sparrowhub.io/project/gh-FCO-Configuration/badge)](https://ci.sparrowhub.io)

Very early stage of development!

=head1 Example


For defining what classes to use as configuration, you can do something like:

=head2 Configuration definition (Test1Config.rakumod)

=begin code :lang<raku>
use v6.d;
use Configuration::Node;

class RootConfig does Configuration::Node {
    has Int      $.a;
    has Int      $.b      = $!a * 2;
    has Int      $.c      = $!b * 3;
}

use Configuration RootConfig
=end code

Then, for using that to write a configuration, it's just question of:

=head2 Configuration (`my-conf.rakuconfig`)

(by default, it searches for configuration on the same dir as the executable
(with the same name adding '.rakuconfig'), on the home directory and on /etc)

=begin code :lang<raku>
use Test1Config;

config {
    .a = 1;
    .c = 42;
}
=end code

It uses the `config` function exported by the module created before
that waits for a block that will expect a builder for the configured
class as the first parameter.

=head2 Program using the configuration:

=begin code :lang<raku>
use Test1Config;

say await config-run :file<examples/test1.rakuconfig>
=end code

On your software you will use the same module where you defined the
configuration, and use it's exported functions to the the populated
configuration class object.

This, with that configuration, will print:


=begin code :lang<raku>
Test1Config.new(a => 1, b => 2, c => 42)
=end code

But you could also make it reload if the file changes:

=begin code :lang<raku>
use Test1Config;

react whenever config-run :file<./my-conf.rakuconfig>, :signal(SIGUSR1) {
    say "Configuration changed: { .raku }";
}
=end code

The whenever will be called every time the configuration change and SIGUSR1 is sent to the process.
It also can watch the configuration file:

=begin code :lang<raku>
use Test1Config;

react whenever config-run :file<./my-conf.rakuconfig>, :watch {
    say "Configuration changed: { .raku }";
}
=end code

And it will reload whenever the file changes.
The `whenever`, with the current configuration, will receive this object:

=begin code :lang<raku>
Test1Config.new(a => 1, b => 2, c => 42)
=end code

If your config declaration changed to something like this:

=begin code :lang<raku>
use Configuration::Node;

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

use Configuration RootConfig

=end code

Your `whenever` will receive an object like this:

=begin code :lang<raku>
RootConfig.new(a => 1, b => 2, c => 42, db => DBConfig.new(host => "localhost", port => 5432, dbname => Str))
=end code

And if you want to change your configuration to populate the DB config, you can do that with something like this:

=begin code :lang<raku>
config {
    .a = 1;
    .c = 42;
    .db: {
        .dbname = "my-database";
    }
}
=end code

And it will generate the object:

=begin code :lang<raku>
Test1Config.new(a => 1, b => 2, c => 42, db => DBConfig.new(host => "localhost", port => 5432, dbname => "my-database"))
=end code

An example with Cro could look like this:

=head2 Config Declaration (ServerConfig.rakumod):

=begin code :lang<raku>
use v6.d;
use Configuration::Node;
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

use Configuration ServerConfig;
=end code

And the code could look something like this:

=begin code :lang<raku>
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
=end code

=end pod
