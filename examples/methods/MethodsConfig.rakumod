use v6.d;

class RootConfig {
    has @.rules;
    method add-rule(Str $rule) {
        @.rules.append: $rule
    }
}

use Configuration RootConfig
