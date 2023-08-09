use v6.d;
use Configuration;

class RootConfig does Configuration::Node {
    has @.rules;
    method add-rule(Str $rule) {
        %*DATA<rules>.append: $rule
    }
}

sub EXPORT {
    generate-exports RootConfig
}
