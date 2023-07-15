use v6.d;

unit role Configuration::Node;

method WHICH {
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