class X::Data::StaticTable is Exception {
    has Str $.message;
    method new($message) { self.bless(:$message) }
}

# vim: expandtab shiftwidth=4
