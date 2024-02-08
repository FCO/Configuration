TITLE
=====

Configuration Module Documentation

SUBTITLE
========

Effortlessly manage configurations in Raku applications

This documentation provides a comprehensive guide on using the Configuration module for Raku. The module is designed to simplify the management of configuration data in Raku applications, making it easier to define, use, and update configurations as needed.

[![Build Status](https://github.com/FCO/Configuration/workflows/test/badge.svg)](https://github.com/FCO/Configuration/actions) [![SparrowCI](https://ci.sparrowhub.io/project/git-FCO-Configuration/badge)](https://ci.sparrowhub.io)

Note: The module is in the early stages of development.

SYNOPSIS
========

This documentation covers the following aspects of the Configuration module:

  * Defining configuration schemas

  * Writing configuration files

  * Utilizing configurations in Raku programs

  * Understanding Configuration Builders

  * Dynamically reloading configurations

  * Handling default configuration file paths

  * Monitoring specific configuration value changes with config-supply

  * Retrieving the current configuration with get-config

  * Obtaining configuration without a Supply with single-config-run

CONFIGURATION DEFINITION
========================

To define your application's configuration structure, create a Raku class that does the `Configuration::Node` role. This class will specify the fields and default values for your configuration.

Example: Defining a Configuration Class
---------------------------------------

```raku
use v6.d;

class RootConfig {
    has Int $.a;
    has Int $.b = $!a * 2;
    has Int $.c = $!b * 3;
}

use Configuration RootConfig;
```

WRITING CONFIGURATION FILES
===========================

Configuration files are written in Raku, allowing you to leverage Raku's syntax for setting configuration values.

Example: Creating a Configuration File (`my-conf.rakuconfig`)
-------------------------------------------------------------

```raku
use Test1Config;

config {
    .a = 1;
    .c = 42;
}
```

UTILIZING CONFIGURATIONS IN YOUR PROGRAM
========================================

To use the defined configurations in your Raku application, simply use the module where the configuration was defined and call the appropriate functions to access the configuration data.

Example: Accessing Configuration in a Raku Program
--------------------------------------------------

```raku
use Test1Config;

say await config-run :file<examples/test1.rakuconfig>;
```

UNDERSTANDING CONFIGURATION BUILDERS
====================================

When utilizing the `config` function to define or modify configurations, it's crucial to understand that the object you interact with is not directly the configuration object itself. Instead, this object is a specialized builder object, designed to accumulate configuration data before creating the final configuration object.

The Role of Configuration Builders
----------------------------------

For each configuration class you define, the Configuration module automatically generates a corresponding builder class. This builder class is named by appending the word "Builder" to the name of your configuration class. The primary purpose of the builder is to provide a flexible and error-resistant way to gather configuration data.

Accumulating Configuration Data
-------------------------------

The builder class contains read-write (rw) methods corresponding to each attribute defined in your configuration class. These methods are used to set or modify the values of the configuration attributes in a staged manner. By calling these methods, you accumulate the data needed to instantiate the actual configuration object.

Here's how the process works:

1. **Initialization**: When you call the `config` function, the Configuration module instantiates the corresponding builder object based on your configuration class. 2. **Data Accumulation**: As you use the builder's methods to set configuration values, the builder accumulates this data internally. Each method call adjusts the pending configuration state represented by the builder. 3. **Configuration Instantiation**: Once all necessary configuration data is set, the builder uses this accumulated data to create an instance of your configuration class, effectively materializing the final configuration object.

Example: Using a Configuration Builder
--------------------------------------

Consider you have a configuration class named `AppConfig`. The corresponding builder class would be `AppConfigBuilder`.

```raku
class AppConfig {
    has Str $.api_key;
    has Int $.timeout;
}

# Using the builder to set configuration
config {
    .api_key = 'your_api_key_here';
    .timeout = 300;
}
```

In this example, `.api_key` and `.timeout` are methods of the `AppConfigBuilder` object provided to the block by the `config` function. These methods set the values that will be used to instantiate `AppConfig` with the provided values.

This builder pattern allows for a clear separation between the definition of configuration data and its usage, enabling more complex configurations to be defined in an intuitive and error-resistant manner.

DYNAMIC CONFIGURATION RELOADING
===============================

The Configuration module supports dynamic reloading of configurations, allowing your application to respond to changes in configuration without restarting.

Example: Reloading Configuration on File Change
-----------------------------------------------

```raku
use Test1Config;

react whenever config-run :file<./my-conf.rakuconfig>, :watch {
    say "Configuration changed: { .raku }";
}
```

Example: Reloading Configuration on Signal
------------------------------------------

```raku
use Test1Config;

react whenever config-run :file<./my-conf.rakuconfig>, :signal(SIGUSR1) {
    say "Configuration changed: { .raku }";
}
```

USING DEFAULT CONFIGURATION FILE PATHS
======================================

When the file path for a configuration is not explicitly specified, the Configuration module intelligently searches for configuration files in default locations. This feature simplifies the configuration management process by automatically detecting and using configuration files based on standardized naming conventions and common directory locations.

The module follows a hierarchical approach to search for configuration files in the following order:

  * The same directory as the executable, appending `.rakuconfig` to the executable name.

  * The user's home directory.

  * The `/etc` directory, typically used for system-wide configuration files.

Example: Implicit Configuration File Usage
------------------------------------------

```raku
use Test1Config;

# No file path is specified; the module automatically searches for `app.rakuconfig` in default locations.
say await config-run;
```

MONITORING SPECIFIC CONFIGURATION VALUE CHANGES WITH CONFIG-SUPPLY
==================================================================

The `config-supply` function in the Configuration module is a standout feature for applications needing to monitor and react to changes in specific configuration values in real-time. This approach is invaluable for creating highly responsive and adaptable applications that depend on dynamic configuration data.

By returning a `Supply` that emits updates whenever the monitored configuration value changes, `config-supply` facilitates a reactive programming model. This enables developers to specify precisely which configuration values to observe and to define actions that should occur in response to changes in these values.

Focused Monitoring with `config-supply`
---------------------------------------

The purpose of `config-supply` is to offer a targeted and efficient way to watch individual configuration values. This is especially useful in complex applications where certain features or behaviors are controlled by specific configuration settings, and updates to these settings need to be handled promptly.

Example: Reacting to Changes in a Specific Configuration Value
--------------------------------------------------------------

```raku
use Test1Config;

# Reacting to changes in the `.a` configuration value
config-supply(*.a).tap: {
    say ".a has changed: ", $_
};
```

This example highlights the use of `config-supply` to monitor changes to the `.a` configuration value. By tapping into the supply, the application can execute a block of code—in this case, logging the change—whenever `.a` is updated.

Integration with Reactive Programming Patterns
----------------------------------------------

`config-supply` integrates seamlessly with Raku's reactive programming constructs (`react` and `whenever`), allowing for elegant and powerful event-driven programming based on configuration changes.

Example: Dynamic Behavior Adjustment Based on Configuration Changes
-------------------------------------------------------------------

```raku
use Test1Config;

react {
    # Dynamically adjust behavior based on changes to the `.a` value
    whenever config-supply(*.a) -> $new-value {
        say ".a has changed to: $new-value";
    }
}
```

RETRIEVING THE CURRENT CONFIGURATION WITH GET-CONFIG
====================================================

The `get-config` function is a straightforward way to access the current value of your application's configuration. This function returns the current configuration object, allowing for immediate access to its properties without monitoring for changes.

Example: Accessing Current Configuration Values
-----------------------------------------------

```raku
use Test1Config;

# Retrieve the current configuration
my $current-config = get-config();

say "Current configuration: ", $current-config.raku;
```

OBTAINING CONFIGURATION WITHOUT A SUPPLY WITH SINGLE-CONFIG-RUN
===============================================================

While `config-run` provides a `Supply` that emits configuration changes over time, `single-config-run` is designed to return the configuration object a single time. This function is useful when you only need to read the configuration once and do not require a reactive setup to monitor for changes.

Example: Using Single-Config-Run to Access Configuration
--------------------------------------------------------

```raku
use Test1Config;

# Obtain the configuration a single time
my $config = single-config-run();

say "Configuration obtained once: ", $config.raku;
```

By incorporating these functions, developers are equipped with flexible tools for managing configuration according to the needs of their application, whether it's accessing the current configuration state, reacting to changes in real-time, or obtaining the configuration once without further monitoring.

