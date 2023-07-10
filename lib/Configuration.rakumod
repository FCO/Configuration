unit class Configuration;

role Node {
    method WHICH {
        ValueObjAt.new:
        [
            self.^name,
            |(self.^attributes.map({ |(.name.substr(2), $_.get_value(self).WHICH) })),
        ].join: "|"
    }
}

class Builder {
    has $!class is built;
    has %!data;

    multi method FALLBACK(Str $name, &block) {
        my $attr = $!class.^attributes.first({ .name.substr(2) eq $name });
        X::Method::NotFound.new(:method($name)).throw without $attr;
        my $builder = ::?CLASS.new: :class($attr.type);
        my %parent := %*DATA;
        {
            my %*DATA;
            block $builder, |choose-pars(&block, :%parent, :root(%*ROOT));
            %parent{$name} = $attr.type.new(|%*DATA) does Node;
        }
    }
    multi method FALLBACK(Str $name) is rw {
        Proxy.new:
            FETCH => -> $ {
                my $attr = $!class.^attributes.first({ .name.substr(2) eq $name });
                X::Method::NotFound.new(:method($name)).throw without $attr;
                %*DATA{$name}
            },
            STORE => -> $, \value {
                my $attr = $!class.^attributes.first({ .name.substr(2) eq $name });
                X::Method::NotFound.new(:method($name), :typename($!class.^name)).throw without $attr;
                X::TypeCheck::Assignment.new(got => value, expected => $attr.type).throw
                  unless value ~~ $attr.type;
                %*DATA{$name} = value
            }
    }
}

has IO()   $.file;
has        $.watch;
has Signal $.signal;;
has Any:U  $.root is required;

method TWEAK(|) {
    $!watch = $!file if $!watch ~~ Bool && $!watch;
}

method supply-list {
    |(
        ( .watch     with $!watch  ),
        ( signal($_) with $!signal ),
    )
}

sub choose-pars(&block, :$parent, :$root) {
    my %pars is Set = &block.signature.params.grep({ .named }).map({ .name.substr(1) });
    %(
        |(:$parent if %pars<parent>),
        |(:$root   if %pars<root>),
    )
}

method generate-config {
    return sub config(&block) {
        my $builder = Builder.new: :class($!root);
        my %*DATA;
        my %*ROOT := %*DATA;
        block $builder, |choose-pars(&block, :root(%*DATA));
        $!root.new(|%*DATA) does Node;
    }
}

method conf-from-file {
    self.conf-from-string($!file.slurp);
}

method conf-from-string($str) {
    my &config := self.generate-config;
    use MONKEY-SEE-NO-EVAL;
    EVAL $str;
}

multi method single-run(Str $code) {
    self.conf-from-string($code)
}

multi method single-run {
    self.conf-from-file
}

multi method run {
    my $old = 0;
    Supply.merge(Supply.from-list([True]), |self.supply-list)
      .map({self.single-run})
      .squish
      .do: { $old = $_ }
}

proto single-config-run(Mu:U, |) is export {*}

multi single-config-run(Mu:U $root, IO() :$file! where *.f) {
    ::?CLASS.new(:$root, :$file).single-run
}

multi single-config-run(Mu:U $root, Str :$code!) {
    ::?CLASS.new(:$root).single-run(:$code)
}

multi config-run(Mu:U $root, |c) is export {
    ::?CLASS.new(:$root, |c).run
}
