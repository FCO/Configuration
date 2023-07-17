use v6.d;
use Test1Config;

sub another-place is export {
    say get-config;

    # Emits only when `.a` is changed
    config-supply(*.a).tap: { say ".a has changed: ", $_ }

    # Emits only when `.db.host` is changed
    config-supply(*.db.host).tap: { say ".db.host has changed: ", $_ }

    # Emits only when `.db` is changed
    config-supply(*.db).tap: { say ".db has changed: ", $_ }
}

