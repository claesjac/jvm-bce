package JVM::BCE::Reader::Std;

use strict;
use warnings;

use JVM::BCE::Class;

use parent qw(JVM::BCE::Reader);

sub target { 
    return $_[0]->{target};
}

sub read {
    my ($pkg, $path) = @_;
    
    my $target = JVM::BCE::Class->new();
    
    my $self = bless { target => $target }, $pkg;
    
    $self->SUPER::read($path);
    
    return $target;
}

1;
__END__
=pod

=head1 NAME

JVM::BCE::Reader::Std - The "standard" reader which turns your .class file into a JVM::BCE::Class instance

=cut