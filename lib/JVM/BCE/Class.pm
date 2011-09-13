package JVM::BCE::Class;

use strict;
use warnings;

sub new {
    my $pkg = shift;
    my $self = bless {}, $pkg;
    return $self;
}

sub name {}
sub extends {}
    
1;