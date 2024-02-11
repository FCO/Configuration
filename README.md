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

  * Handling Missing Configuration Files with Default Values

  * Dynamically reloading configurations

  * Handling default configuration file paths

  * Monitoring specific configuration value changes with config-supply

  * Configuration Error Handling and Resilience

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

  * **Initialization**: When you call the `config` function, the Configuration module instantiates the corresponding builder object based on your configuration class.

  * **Data Accumulation**: As you use the builder's methods to set configuration values, the builder accumulates this data internally. Each method call adjusts the pending configuration state represented by the builder.

  * **Configuration Instantiation**: Once all necessary configuration data is set, the builder uses this accumulated data to create an instance of your configuration class, effectively materializing the final configuration object.

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

HANDLING MISSING CONFIGURATION FILES WITH DEFAULT VALUES
========================================================

The Configuration module is designed to ensure maximum uptime and resilience for your application by employing a robust defaulting mechanism. In situations where a configuration file is expected but does not exist, the module gracefully defaults to using predefined values specified within your configuration class. This feature guarantees that your application can start and run even in the absence of an external configuration file.

Default Value Mechanism
-----------------------

Upon initialization, if the Configuration module does not find the specified configuration file, it does not halt the application or throw an error. Instead, it proceeds to instantiate the configuration object using the default values declared in the configuration class. This behavior is critical for maintaining application operability, especially in new deployments or environments where the configuration file may not yet be set up.

Example: Specifying and Utilizing Default Values
------------------------------------------------

```raku
class AppConfig {
    has Str $.api_key = 'default_api_key';
    has Int $.timeout = 30;
}

use Configuration AppConfig;
```

In this example, `AppConfig` specifies default values for `api_key` and `timeout`. If the Configuration module does not find an external configuration file upon application start, it will create an `AppConfig` object with these default values. Consequently, the application remains functional and uses these defaults as its operational parameters.

Advantages of Using Default Values
----------------------------------

  * **Flexibility**: Allows the application to run in diverse environments without requiring a configuration file to be present initially.

  * **Simplicity**: Simplifies development and testing by not mandating the existence of a configuration file, especially in early stages of development.

  * **Reliability**: Enhances the reliability of the application by ensuring it can always start up, reducing the risk of failures due to missing configuration data.

This defaulting mechanism underscores the Configuration module's design philosophy of resilience and ease of use, ensuring that applications remain robust and user-friendly across various deployment scenarios.

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

CONFIGURATION ERROR HANDLING AND RESILIENCE
===========================================

A key feature of the Configuration module is its robust error handling mechanism during runtime configuration changes. When the module detects an error in the configuration—such as invalid data types, missing required fields, or any condition that violates the configuration schema—it is designed to issue a warning rather than terminating the application. This approach ensures that your application remains operational, continuing with the last known correct configuration.

Graceful Error Management
-------------------------

The Configuration module adopts a non-intrusive error management strategy to maximize application uptime and resilience. In scenarios where a runtime configuration change introduces errors:

  * The module logs a warning detailing the nature of the error, making it visible to developers or system administrators for troubleshooting.

  * It retains the previous valid configuration state, ensuring that the application continues to run with known-good settings.

  * Subsequent attempts to apply configuration changes will follow the same pattern—errors will result in warnings, and only valid changes will be applied.

Benefits of This Approach
-------------------------

This error handling strategy offers several benefits:

  * `Reliability`: Your application remains operational, avoiding downtime due to configuration issues.

  * `Safety`: Ensures that only valid configurations are applied, protecting the application from unstable states.

  * `Visibility`: Provides clear feedback on configuration errors, aiding in quick diagnosis and correction.

By prioritizing continuity and stability, the Configuration module helps maintain the integrity of your application's runtime environment, even in the face of configuration errors. This design choice reflects a commitment to production-grade resilience and operability.

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

