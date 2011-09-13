package JVM::BCE::Class;

use strict;
use warnings;

sub new {
    my $pkg = shift;
    my $self = bless {}, $pkg;
    return $self;
}

1;