
# -------------------- this does NOT work --------------------

use MooseX::Declare;
class MUser extends DbUser {
        extends 'Class::Accessor::Fast'; # NEEDED!?
        has hotstuff => (is => 'rw', isa => "Str");
        __PACKAGE__->meta->make_immutable(inline_constructor => 0);
}

1;
