# Test1Config exports many thing, 3 of them
# are the `config-run`, `get-config` and `config-supply`
# subs. COMMA seems to not be recognizing
# any of its exports (not even the config sub).
# That might be a bug on COMMA.
use Test1Config;

react {
    whenever config-run :file<examples/test1/test1.rakuconfig>, :watch {
        say "Configuration changed: { .raku }";
        start {
            await Promise.in: 5;
            another-place;
        }
    }
    whenever Supply.interval: 5 {
        say "the last config was: ", get-config;
    }
}

sub another-place {
    config-supply.tap: { say "config supply: ", $_ }
}