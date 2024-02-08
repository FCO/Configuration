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
      unless $!root ~~ Configuration::Node {
          $!root.^add_role: Configuration::Node;
          $!root.^compose
      }
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
        "&EXPORT" => sub {
            generate-exports $node
        }
}

multi EXPORT {
    Map.new:
        "Configuration" => Configuration,
        "Configuration::Node" => Configuration::Node,
}

=begin pod

=TITLE Configuration Module Documentation
=SUBTITLE Effortlessly manage configurations in Raku applications

This documentation provides a comprehensive guide on using the Configuration module for Raku. The module is designed to simplify the management of configuration data in Raku applications, making it easier to define, use, and update configurations as needed.

[![Build Status](https://github.com/FCO/Configuration/workflows/test/badge.svg)](https://github.com/FCO/Configuration/actions)
[![SparrowCI](https://ci.sparrowhub.io/project/git-FCO-Configuration/badge)](https://ci.sparrowhub.io)

Note: The module is in the early stages of development.

=head1 SYNOPSIS

This documentation covers the following aspects of the Configuration module:

=item Defining configuration schemas
=item Writing configuration files
=item Utilizing configurations in Raku programs
=item Dynamically reloading configurations
=item Handling default configuration file paths
=item Monitoring specific configuration value changes with config-supply
=item Retrieving the current configuration with get-config
=item Obtaining configuration without a Supply with single-config-run

=head1 CONFIGURATION DEFINITION

To define your application's configuration structure, create a Raku class that does the `Configuration::Node` role. This class will specify the fields and default values for your configuration.

=head2 Example: Defining a Configuration Class

=begin code :lang<raku>
use v6.d;
use Configuration::Node;

class RootConfig does Configuration::Node {
    has Int $.a;
    has Int $.b = $!a * 2;
    has Int $.c = $!b * 3;
}

use Configuration RootConfig;
=end code

The Configuration module simplifies this process by automatically applying the `Configuration::Node` role to your root configuration class if it isn't already specified, ensuring consistent behavior and feature availability across all configuration classes.

=head2 Automatic Configuration::Node Role Application

When you define a configuration class and use it with `use Configuration`, the module checks if your class does the `Configuration::Node` role. If the class does not explicitly use `Configuration::Node`, the module will automatically add it. This feature ensures that all necessary functionalities for configuration management are available, even if the developer forgets to specify the role.

=head2 Example: Defining a Configuration Class Without Explicitly Using Configuration::Node

=begin code :lang<raku>
use v6.d;

class RootConfig {
    has Int $.a;
    has Int $.b = $!a * 2;
    has Int $.c = $!b * 3;
}

use Configuration RootConfig;
=end code

In this example, even though `RootConfig` does not explicitly `do` the `Configuration::Node` role, the Configuration module automatically applies it. This ensures that `RootConfig` has all the capabilities needed to work seamlessly with the Configuration module, such as automatic attribute initialization, type checking, and more.

This automatic role application feature is designed to reduce boilerplate code and make the module more user-friendly, allowing developers to focus on defining their configuration's structure and logic without worrying about the underlying role mechanics.

=head1 WRITING CONFIGURATION FILES

Configuration files are written in Raku, allowing you to leverage Raku's syntax for setting configuration values.

=head2 Example: Creating a Configuration File (`my-conf.rakuconfig`)

=begin code :lang<raku>
use Test1Config;

config {
    .a = 1;
    .c = 42;
}
=end code

=head1 UTILIZING CONFIGURATIONS IN YOUR PROGRAM

To use the defined configurations in your Raku application, simply use the module where the configuration was defined and call the appropriate functions to access the configuration data.

=head2 Example: Accessing Configuration in a Raku Program

=begin code :lang<raku>
use Test1Config;

say await config-run :file<examples/test1.rakuconfig>;
=end code

=head1 DYNAMIC CONFIGURATION RELOADING

The Configuration module supports dynamic reloading of configurations, allowing your application to respond to changes in configuration without restarting.

=head2 Example: Reloading Configuration on File Change

=begin code :lang<raku>
use Test1Config;

react whenever config-run :file<./my-conf.rakuconfig>, :watch {
    say "Configuration changed: { .raku }";
}
=end code

=head2 Example: Reloading Configuration on Signal

=begin code :lang<raku>
use Test1Config;

react whenever config-run :file<./my-conf.rakuconfig>, :signal(SIGUSR1) {
    say "Configuration changed: { .raku }";
}
=end code

=head1 USING DEFAULT CONFIGURATION FILE PATHS

When the file path for a configuration is not explicitly specified, the Configuration module intelligently searches for configuration files in default locations. This feature simplifies the configuration management process by automatically detecting and using configuration files based on standardized naming conventions and common directory locations.

The module follows a hierarchical approach to search for configuration files in the following order:

=item The same directory as the executable, appending `.rakuconfig` to the executable name.
=item The user's home directory.
=item The `/etc` directory, typically used for system-wide configuration files.

=head2 Example: Implicit Configuration File Usage

=begin code :lang<raku>
use Test1Config;

# No file path is specified; the module automatically searches for `app.rakuconfig` in default locations.
say await config-run;
=end code

=head1 MONITORING SPECIFIC CONFIGURATION VALUE CHANGES WITH CONFIG-SUPPLY

The `config-supply` function in the Configuration module is a standout feature for applications needing to monitor and react to changes in specific configuration values in real-time. This approach is invaluable for creating highly responsive and adaptable applications that depend on dynamic configuration data.

By returning a `Supply` that emits updates whenever the monitored configuration value changes, `config-supply` facilitates a reactive programming model. This enables developers to specify precisely which configuration values to observe and to define actions that should occur in response to changes in these values.

=head2 Focused Monitoring with `config-supply`

The purpose of `config-supply` is to offer a targeted and efficient way to watch individual configuration values. This is especially useful in complex applications where certain features or behaviors are controlled by specific configuration settings, and updates to these settings need to be handled promptly.

=head2 Example: Reacting to Changes in a Specific Configuration Value

=begin code :lang<raku>
use Test1Config;

# Reacting to changes in the `.a` configuration value
config-supply(*.a).tap: {
    say ".a has changed: ", $_
};
=end code

This example highlights the use of `config-supply` to monitor changes to the `.a` configuration value. By tapping into the supply, the application can execute a block of code—in this case, logging the change—whenever `.a` is updated.

=head2 Integration with Reactive Programming Patterns

`config-supply` integrates seamlessly with Raku's reactive programming constructs (`react` and `whenever`), allowing for elegant and powerful event-driven programming based on configuration changes.

=head2 Example: Dynamic Behavior Adjustment Based on Configuration Changes

=begin code :lang<raku>
use Test1Config;

react {
    # Dynamically adjust behavior based on changes to the `.a` value
    whenever config-supply(*.a) -> $new-value {
        say ".a has changed to: $new-value";
    }
}
=end code

=head1 RETRIEVING THE CURRENT CONFIGURATION WITH GET-CONFIG

The `get-config` function is a straightforward way to access the current value of your application's configuration. This function returns the current configuration object, allowing for immediate access to its properties without monitoring for changes.

=head2 Example: Accessing Current Configuration Values

=begin code :lang<raku>
use Test1Config;

# Retrieve the current configuration
my $current-config = get-config();

say "Current configuration: ", $current-config.raku;
=end code

=head1 OBTAINING CONFIGURATION WITHOUT A SUPPLY WITH SINGLE-CONFIG-RUN

While `config-run` provides a `Supply` that emits configuration changes over time, `single-config-run` is designed to return the configuration object a single time. This function is useful when you only need to read the configuration once and do not require a reactive setup to monitor for changes.

=head2 Example: Using Single-Config-Run to Access Configuration

=begin code :lang<raku>
use Test1Config;

# Obtain the configuration a single time
my $config = single-config-run();

say "Configuration obtained once: ", $config.raku;
=end code

By incorporating these functions, developers are equipped with flexible tools for managing configuration according to the needs of their application, whether it's accessing the current configuration state, reacting to changes in real-time, or obtaining the configuration once without further monitoring.

=end pod
