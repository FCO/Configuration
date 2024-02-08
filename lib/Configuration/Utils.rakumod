use v6.d;
use experimental :cached;
unit module Configuration::Utils;
use Configuration::Node;

sub choose-pars(&block, :$parent, :$root) is export {
    my %pars is Set = &block.signature.params.grep({ .named }).map({ .name.substr(1) });
    %(
        |(:$parent if %pars<parent>),
        |(:$root   if %pars<root>),
    )
}

sub generate-builder-class(Configuration::Node:U $node) is cached is export {
    my $builder = Metamodel::ClassHOW.new_type: :name($node.^name ~ "Builder");
    $builder.^add_parent: $node;
    $builder.^add_method: "raku", my method {
      self.gist
    };
    $builder.^add_method: "gist", my method {
      do with self {
        join ",\n", do for self.^methods -> &meth {
            "{ &meth.name } => ???"
        }
      } else {
        "({ self.^name }})"
      }
    };
    for $node.^attributes.grep(*.has_accessor) -> Attribute $attr (::T :$type, |) {
        my $name = $attr.name.substr: 2;
        my $meth = do if $attr.type !~~ Configuration::Node {
            $builder.^add_method: $name, method () is rw {
                Proxy.new:
                        FETCH => -> $self {
                            %*DATA{$name} := %*DATA{$name}:exists
                                    ?? %*DATA{$name}
                                    !! $attr.build
                                      // $attr.type ~~ Positional
                                        ?? []
                                        !! $attr.type ~~ Associative
                                          ?? %()
                                          !! $attr.type
                        },
                        STORE => -> $self, $value {
                            if $attr.type !~~ (Positional|Associative) && $value !~~ $attr.type {
                                X::TypeCheck::Assignment.new(got => $value, expected => $attr.type).throw;
                            }
                            %*DATA{$name} := $value<>
                        }
            }
        } else {
            $builder.^add_method: $name, method (&block) {
                my $builder = generate-builder-class($attr.type);
                my %parent := %*DATA;
                {
                    my %*DATA;
                    block $builder, |choose-pars(&block, :%parent, :root(%*ROOT));
                    %parent{$name} = $attr.type.new(|%*DATA);
                }
            }
        }
        $meth.set_why: $_ with $attr.WHY;
    }
    $builder.^compose;
    $builder
}

sub get-nodes(Configuration::Node $root) is export is cached {
    multi take-nodes(Configuration::Node $_) {
        .take;
        return Empty unless .HOW.^can: "attributes";
        for .^attributes {
            .type.&take-nodes
        }
    }
    multi take-nodes(@val) { take-nodes @val.of }
    multi take-nodes(%val) { take-nodes %val.of }
    multi take-nodes($_) {
        return Empty unless .HOW.^can: "attributes";
        for .^attributes {
            .type.&take-nodes
        }
    }
    multi take-nodes(Mu) {}
    CATCH { default { note $_ } }
    gather { take-nodes $root }\
        .grep({ .^name && $_ ~~ Configuration::Node })\
        .duckmap({ "{ .^name }Builder" => generate-builder-class $_ })\
        .cache
}
