#!/usr/bin/env raku
use lib ".";
use MethodsConfig;

say await config-run :file<examples/methods/methods.rakuconfig>;
