use MooseX::Declare;

use 5.010;

use TypeLib;

class BusinessLogic {
        method hello(TypeLib::XAccount $act) {
                say "HELLO ", $act->name;
        }
}

