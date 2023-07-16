#!/usr/bin/env raku
use lib ".";
use Test1Config;

subset FilePath of Str where *.IO.f;
my FilePath $default-file = "./test1.rakuconfig";

multi MAIN(FilePath :$file = $default-file, Bool :single($)! where *.so) {
    say "single run";
    say await config-run :$file
}

multi MAIN(FilePath :$file = $default-file, Bool :no-signal($)! where *.so) {
    say "watching file";
    react whenever config-run :$file, :watch {
        say "Configuration changed: { .raku }"
    }
}

multi MAIN(FilePath :$file = $default-file, Signal :$signal = SIGUSR1) {
    say "wait for signal";
    react whenever config-run :$file, :$signal {
        say "Configuration changed: { .raku }"
		}
}
