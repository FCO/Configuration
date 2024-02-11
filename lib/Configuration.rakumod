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
                      die "Error on configuration file: $_";
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
              die "Error loading file $!file: $_"
          }
      }
      unless $!file ~~ :f {
          note "Configuration file ($!file) not found, using default configuration";
          return self.generate-config.(-> | {;})
      }
      EVALFILE $!file
  }

  method conf-from-string($str) is hidden-from-backtrace {
      CATCH {
          default {
              die "Error loading configuration: $_"
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
        .map({
            CATCH {
                default {
                    if $!current {
                        note .message
                    } else {
                        .rethrow
                    }
                }
            }
            self.single-run
        })
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
=item Understanding Configuration Builders
=item Handling Missing Configuration Files with Default Values
=item Dynamically reloading configurations
=item Handling default configuration file paths
=item Monitoring specific configuration value changes with config-supply
=item Configuration Error Handling and Resilience
=item Retrieving the current configuration with get-config
=item Obtaining configuration without a Supply with single-config-run

=head1 CONFIGURATION DEFINITION

To define your application's configuration structure, create a Raku class that does the C<Configuration::Node> role. This class will specify the fields and default values for your configuration.

=head2 Example: Defining a Configuration Class

=begin code :lang<raku>
use v6.d;

class RootConfig {
    has Int $.a;
    has Int $.b = $!a * 2;
    has Int $.c = $!b * 3;
}

use Configuration RootConfig;
=end code

=head1 WRITING CONFIGURATION FILES

Configuration files are written in Raku, allowing you to leverage Raku's syntax for setting configuration values.

=head2 Example: Creating a Configuration File (C<my-conf.rakuconfig>)

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

=head1 UNDERSTANDING CONFIGURATION BUILDERS

When utilizing the C<config> function to define or modify configurations, it's crucial to understand that the object you interact with is not directly the configuration object itself. Instead, this object is a specialized builder object, designed to accumulate configuration data before creating the final configuration object.

=head2 The Role of Configuration Builders

For each configuration class you define, the Configuration module automatically generates a corresponding builder class. This builder class is named by appending the word "Builder" to the name of your configuration class. The primary purpose of the builder is to provide a flexible and error-resistant way to gather configuration data.

=head2 Accumulating Configuration Data

The builder class contains read-write (rw) methods corresponding to each attribute defined in your configuration class. These methods are used to set or modify the values of the configuration attributes in a staged manner. By calling these methods, you accumulate the data needed to instantiate the actual configuration object.

Here's how the process works:

=item B<Initialization>: When you call the C<config> function, the Configuration module instantiates the corresponding builder object based on your configuration class.
=item B<Data Accumulation>: As you use the builder's methods to set configuration values, the builder accumulates this data internally. Each method call adjusts the pending configuration state represented by the builder.
=item B<Configuration Instantiation>: Once all necessary configuration data is set, the builder uses this accumulated data to create an instance of your configuration class, effectively materializing the final configuration object.

=head2 Example: Using a Configuration Builder

Consider you have a configuration class named C<AppConfig>. The corresponding builder class would be C<AppConfigBuilder>.

=begin code :lang<raku>
class AppConfig {
    has Str $.api_key;
    has Int $.timeout;
}

# Using the builder to set configuration
config {
    .api_key = 'your_api_key_here';
    .timeout = 300;
}
=end code

In this example, C<.api_key> and C<.timeout> are methods of the C<AppConfigBuilder> object provided to the block by the C<config> function. These methods set the values that will be used to instantiate C<AppConfig> with the provided values.

This builder pattern allows for a clear separation between the definition of configuration data and its usage, enabling more complex configurations to be defined in an intuitive and error-resistant manner.

=head1 HANDLING MISSING CONFIGURATION FILES WITH DEFAULT VALUES

The Configuration module is designed to ensure maximum uptime and resilience for your application by employing a robust defaulting mechanism. In situations where a configuration file is expected but does not exist, the module gracefully defaults to using predefined values specified within your configuration class. This feature guarantees that your application can start and run even in the absence of an external configuration file.

=head2 Default Value Mechanism

Upon initialization, if the Configuration module does not find the specified configuration file, it does not halt the application or throw an error. Instead, it proceeds to instantiate the configuration object using the default values declared in the configuration class. This behavior is critical for maintaining application operability, especially in new deployments or environments where the configuration file may not yet be set up.

=head2 Example: Specifying and Utilizing Default Values

=begin code :lang<raku>
class AppConfig does Configuration::Node {
    has Str $.api_key = 'default_api_key';
    has Int $.timeout = 30;
}

use Configuration AppConfig;
=end code

In this example, C<AppConfig> specifies default values for C<api_key> and C<timeout>. If the Configuration module does not find an external configuration file upon application start, it will create an C<AppConfig> object with these default values. Consequently, the application remains functional and uses these defaults as its operational parameters.

=head2 Advantages of Using Default Values

=item B<Flexibility>: Allows the application to run in diverse environments without requiring a configuration file to be present initially.
=item B<Simplicity>: Simplifies development and testing by not mandating the existence of a configuration file, especially in early stages of development.
=item B<Reliability>: Enhances the reliability of the application by ensuring it can always start up, reducing the risk of failures due to missing configuration data.

This defaulting mechanism underscores the Configuration module's design philosophy of resilience and ease of use, ensuring that applications remain robust and user-friendly across various deployment scenarios.

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

=item The same directory as the executable, appending C<.rakuconfig> to the executable name.
=item The user's home directory.
=item The C</etc> directory, typically used for system-wide configuration files.

=head2 Example: Implicit Configuration File Usage

=begin code :lang<raku>
use Test1Config;

# No file path is specified; the module automatically searches for `app.rakuconfig` in default locations.
say await config-run;
=end code

=head1 MONITORING SPECIFIC CONFIGURATION VALUE CHANGES WITH CONFIG-SUPPLY

The C<config-supply> function in the Configuration module is a standout feature for applications needing to monitor and react to changes in specific configuration values in real-time. This approach is invaluable for creating highly responsive and adaptable applications that depend on dynamic configuration data.

By returning a C<Supply> that emits updates whenever the monitored configuration value changes, C<config-supply> facilitates a reactive programming model. This enables developers to specify precisely which configuration values to observe and to define actions that should occur in response to changes in these values.

=head2 Focused Monitoring with C<config-supply>

The purpose of C<config-supply> is to offer a targeted and efficient way to watch individual configuration values. This is especially useful in complex applications where certain features or behaviors are controlled by specific configuration settings, and updates to these settings need to be handled promptly.

=head2 Example: Reacting to Changes in a Specific Configuration Value

=begin code :lang<raku>
use Test1Config;

# Reacting to changes in the `.a` configuration value
config-supply(*.a).tap: {
    say ".a has changed: ", $_
};
=end code

This example highlights the use of C<config-supply> to monitor changes to the C<.a> configuration value. By tapping into the supply, the application can execute a block of code—in this case, logging the change—whenever C<.a> is updated.

=head2 Integration with Reactive Programming Patterns

C<config-supply> integrates seamlessly with Raku's reactive programming constructs (C<react> and C<whenever>), allowing for elegant and powerful event-driven programming based on configuration changes.

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

=head1 CONFIGURATION ERROR HANDLING AND RESILIENCE

A key feature of the Configuration module is its robust error handling mechanism during runtime configuration changes. When the module detects an error in the configuration—such as invalid data types, missing required fields, or any condition that violates the configuration schema—it is designed to issue a warning rather than terminating the application. This approach ensures that your application remains operational, continuing with the last known correct configuration.

=head2 Graceful Error Management

The Configuration module adopts a non-intrusive error management strategy to maximize application uptime and resilience. In scenarios where a runtime configuration change introduces errors:

=item The module logs a warning detailing the nature of the error, making it visible to developers or system administrators for troubleshooting.
=item It retains the previous valid configuration state, ensuring that the application continues to run with known-good settings.
=item Subsequent attempts to apply configuration changes will follow the same pattern—errors will result in warnings, and only valid changes will be applied.

=head2 Benefits of This Approach

This error handling strategy offers several benefits:

=item C<Reliability>: Your application remains operational, avoiding downtime due to configuration issues.
=item C<Safety>: Ensures that only valid configurations are applied, protecting the application from unstable states.
=item C<Visibility>: Provides clear feedback on configuration errors, aiding in quick diagnosis and correction.

By prioritizing continuity and stability, the Configuration module helps maintain the integrity of your application's runtime environment, even in the face of configuration errors. This design choice reflects a commitment to production-grade resilience and operability.

=head1 RETRIEVING THE CURRENT CONFIGURATION WITH GET-CONFIG

The C<get-config> function is a straightforward way to access the current value of your application's configuration. This function returns the current configuration object, allowing for immediate access to its properties without monitoring for changes.

=head2 Example: Accessing Current Configuration Values

=begin code :lang<raku>
use Test1Config;

# Retrieve the current configuration
my $current-config = get-config();

say "Current configuration: ", $current-config.raku;
=end code

=head1 OBTAINING CONFIGURATION WITHOUT A SUPPLY WITH SINGLE-CONFIG-RUN

While C<config-run> provides a C<Supply> that emits configuration changes over time, C<single-config-run> is designed to return the configuration object a single time. This function is useful when you only need to read the configuration once and do not require a reactive setup to monitor for changes.

=head2 Example: Using Single-Config-Run to Access Configuration

=begin code :lang<raku>
use Test1Config;

# Obtain the configuration a single time
my $config = single-config-run();

say "Configuration obtained once: ", $config.raku;
=end code

By incorporating these functions, developers are equipped with flexible tools for managing configuration according to the needs of their application, whether it's accessing the current configuration state, reacting to changes in real-time, or obtaining the configuration once without further monitoring.

=end pod
