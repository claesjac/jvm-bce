package JVM::BCE::Reader;

use strict;
use warnings;

use Carp qw(croak);

sub read {
    my ($self, $path) = @_;
    
    open my $io, "<", $path or croak "Can't read ${path}: $!";
}

1;