use v6.d;
use Configuration::Node;

class RootConfig does Configuration::Node {
    has @.rules;
    method add-rule(Str $rule) {
        @.rules.append: $rule
    }
}

use Configuration RootConfig
