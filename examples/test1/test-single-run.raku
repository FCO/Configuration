use Test1Config;

say await config-run :file<examples/test1/test1.rakuconfig>;

# other part of the code base;

say get-config;
