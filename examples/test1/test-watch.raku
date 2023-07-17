# Test1Config exports many thing, 3 of them
# are the `config-run`, `get-config` and `config-supply`
# subs. COMMA seems to not be recognizing
# any of its exports (not even the config sub).
# That might be a bug on COMMA.
use Test1Config;
use AnotherPlace;

react {
    # Emits when anything changed on the file
    # I mean the values
    whenever config-run :file<examples/test1/test1.rakuconfig>, :watch {
        say "Configuration changed: { .raku }";
    }
    whenever Promise.in: 5 {
        # A different place on the code base
        # It will print averytime there are changes on:
        # - .a
        # - .db
        # - .db.host
        another-place;
    }
    whenever Supply.interval: 5 {
        # Gets the last configuration value
        say "the last config was: ", get-config;
    }
}