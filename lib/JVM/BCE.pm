package JVM::BCE;

use strict;
use warning;

our $VERSION = "0.01";

sub read {
    require JVM::BCE::Reader::Std;
    
    return JVM::BCE::Reader::Std->read(pop)
}

1;
=pod

=head1 NAME

JVM::BCE - JVM ByteCode (Engineering | Experimentation | Excitement)

=head1 DESCRIPTION

This is a module for reading, manipulating, generating, writing JVM bytecode (and class files).

=cut


