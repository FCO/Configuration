use Test1Config;

react whenever config-run :file<examples/test1/test1.rakuconfig>, :watch {
    say "Configuration changed: { .raku }";
}
