use v6.d;

unit role Configuration::Node;

multi method WHICH(::?CLASS:U:) {
    ValueObjAt.new: self.^name
}

multi method WHICH(::?CLASS:D:) {
    ValueObjAt.new:
            [
                self.^name,
                |(
                    self.^attributes.map({
                        |(
                            .name.substr(2),
                            .get_value(self).WHICH
                        )
                    })
                ),
            ].join: "|"
}
