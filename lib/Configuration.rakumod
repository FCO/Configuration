unit class Configuration;
#use Configuration::Builder;
use Configuration::Utils;
use Configuration::Node;

has IO()   $.file;
has        $.watch;
has Signal $.signal;
has Any:U  $.root   is required;
has Any    $.current;
has Supply $.supply;

submethod TWEAK(|) {
    $!watch = $!file if $!watch ~~ Bool && $!watch;
}

method supply-list {
    |(
        ( .watch     with $!watch  ),
        ( signal($_) with $!signal ),
    )
}

role Generator[::T $builder] {
    method gen($root) {
        # return sub config(&block:(T)) {
        return sub config(&block) { # Should it be typed?
            CATCH {
                default {
                    note "Error on configuration file: $_";
                }
            }
            my %*DATA;
            my %*ROOT := %*DATA;
            block $builder, |choose-pars(&block, :root(%*DATA));
            $root.new(|%*DATA);
        }
    }
}

method generate-config {
    my $builder = generate-builder-class $!root;
    Generator[$builder].gen($!root)
}

method conf-from-file is hidden-from-backtrace {
    self.conf-from-string($!file.slurp);
}

method conf-from-string($str) is hidden-from-backtrace {
    use MONKEY-SEE-NO-EVAL;
    EVAL $str;
}

multi method single-run(Str $code) is hidden-from-backtrace {
    self.conf-from-string($code)
}

multi method single-run is hidden-from-backtrace {
    self.conf-from-file;
}

multi method run is hidden-from-backtrace {
    $!supply = Supply.merge(Supply.from-list([True]), |self.supply-list)
      .map({try self.single-run})
      .grep(*.defined)
      .squish
      .do: { $!current = $_ }
}

proto single-config-run(Any:U, |) is export is hidden-from-backtrace {*}

multi single-config-run(Any:U $root, IO() :$file! where *.f) is hidden-from-backtrace {
    ::?CLASS.new(:$root, :$file).single-run
}

multi single-config-run(Any:U $root, Str :$code!) is hidden-from-backtrace {
    ::?CLASS.new(:$root).single-run(:$code)
}

multi config-run(Any:U $root, |c) is export is hidden-from-backtrace {
    ::?CLASS.new(:$root, |c).run
}

sub generate-config(Any:U $root) is export {
    ::?CLASS.new(:$root).generate-config
}

sub generate-exports(Any:U $root) is export {
    my $obj = ::?CLASS.new(:$root);
    Map.new:
        '&single-config-run' => -> :$file, :$code {
            $obj.single-run:
                    |(:$file with $file),
                    |(:$code with $code),
        },
        '&config-run'        => ->
            IO()     :$file! where *.e,
                     :$watch is copy,
            Signal() :$signal
        {
            $watch = $watch
                ?? $file
                !! Nil
                if $watch ~~ Bool;

            $obj .= clone(
                |(file   => $_ with $file),
                |(watch  => $_ with $watch),
                |(signal => $_ with $signal),
            );
            $obj.run
        },
        '&config-supply'     => { $obj.supply },
        '&get-config'        => { $obj.current },
        '&config'            => $obj.generate-config,
        'ConfigClass'        => generate-builder-class($root),
        |get-nodes($root),
    ;
}

sub EXPORT {
    Map.new:
        "Configuration"       => Configuration,
        "Configuration::Node" => Configuration::Node,
}
