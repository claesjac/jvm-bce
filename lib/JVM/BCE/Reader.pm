package JVM::BCE::Reader;

use strict;
use warnings;

use Carp qw(croak);

sub _read_bytes($$$) {
    my ($io, $expect, $type) = @_;
    my $buffer;
    $io->read($buffer, $expect) == $expect or croak "Couldn't read ${type}";
    return $buffer;
}

sub _read_short { return unpack "n", _read_bytes shift, 2, "short" }
sub _read_int { return unpack "N", _read_bytes shift, 4, "int" }
sub _read_float { return unpack "f>", _read_bytes shift, 4, "float" }
sub _read_double { return unpack "d>", _read_bytes shift, 8, "double" }

sub _read_long {
    my ($high, $low) = unpack "NN", _read_bytes shift, 8, "long";
    my $value = ($high * (2**32)) + $low;    
    return $value;
}

sub _read_short_short { return unpack "nn", _read_bytes shift, 4, "two shorts"; }

sub _read_reference { return unpack "Cn", _read_bytes shift, 3, "reference"; }

sub _read_utf8 {
    my $io = shift;
    my $len = _read_short($io);
    my ($str) = unpack "a*", _read_bytes $io, $len, "utf8 data";
    require utf8;
    utf8::upgrade($str);
    return $str;
}

my %CP_TagName = (
    7   => "CONSTANT_Class",
    9   => "CONSTANT_Fieldref",
    10  => "CONSTANT_Methodref",
    11  => "CONSTANT_InterfaceMethodref",
    8   => "CONSTANT_String",
    3   => "CONSTANT_Integer",
    4   => "CONSTANT_Float",
    5   => "CONSTANT_Long",
    6   => "CONSTANT_Double",
    12  => "CONSTANT_NameAndType",
    1   => "CONSTANT_Utf8",
    15  => "CONSTANT_MethodHandle",
    16  => "CONSTANT_MethodType",
    18  => "CONSTANT_InvokeDynamic",
);

my %CP_Reader = (
    7   => sub { return (1, _read_short(shift)) },
    9   => sub { return (1, _read_short_short(shift)) },
    10  => sub { return (1, _read_short_short(shift)) },
    11  => sub { return (1, _read_short_short(shift)) },
    8   => sub { return (1, _read_short(shift)) },
    3   => sub { return (1, _read_int(shift)) },
    4   => sub { return (1, _read_float(shift)) },
    5   => sub { return (2, _read_long(shift)) },
    6   => sub { return (2, _read_double(shift)) },
    12  => sub { return (1, _read_short_short(shift)) },
    1   => sub { return (1, _read_utf8(shift)) },
    15  => sub { return (1, _read_reference(shift)) },
    16  => sub { return (1, _read_short(shift)) },
    18  => sub { return (1, _read_short_short(shift)) },
);

sub read {
    my ($self, $path) = @_;
    
    open my $io, "<", $path or croak "Can't read ${path}: $!";
    
    my $buffer;
    
    # Header is <u4 magic>, <u2 minor>, <u2 major>
    {
        $io->read($buffer, 8) == 8 or croak "Couldn't read header";
        my ($magic, $minor, $major) = unpack "Nnn", $buffer;
        $magic == 0xcafebabe or croak sprintf "Expected magic '0xcafebabe' but got '0x%x'", $magic;
        $self->handle_magic($magic);
        $self->handle_version($major . ".". $minor);
    }
    
    # Constant pool
    my @constant_pool;
    {
        $io->read($buffer, 2) == 2 or croak "Couldn't read constant pool count";
        my ($cp_count) = unpack "n", $buffer;
        $cp_count--;
        $self->handle_begin_constant_pool($cp_count);
        
        my $ix = 1;
        while ($cp_count-- > 0) {
            $io->read($buffer, 1) == 1 or croak "Couldn't read constant pool item tag";
            my ($tag) = unpack "C", $buffer;
            croak "Unknown constant pool tag ${tag}" unless exists $CP_Reader{$tag};
            my ($ix_offset, @entry) = $CP_Reader{$tag}->($io);        
            $self->handle_constant_pool_entry($ix, $CP_TagName{$tag}, @entry);
            $constant_pool[$ix] = \@entry;
            $ix += $ix_offset;
        }
        
        $self->handle_end_constant_pool();
        
    }
    
    # Class declaration
    {
        $io->read($buffer, 2) == 2 or croak "Couldn't read access flags";
        my ($access_flags) = unpack "n", $buffer;
        $self->handle_class_access_flags($access_flags);

        $io->read($buffer, 4) == 4 or croak "Couldn't read class and superclass cp indices";
        my ($this_class, $super_class) = unpack "nn", $buffer;
        my $name_index = $constant_pool[$this_class]->[0];
        $self->handle_this_class($this_class, $constant_pool[$this_class], $constant_pool[$name_index]->[0]);

        if ($super_class) {
            my $name_index = $constant_pool[$super_class]->[0];
            $self->handle_super_class($super_class, $constant_pool[$super_class], $constant_pool[$name_index]->[0]);
        }
        
        $io->read($buffer, 2) == 2 or croak "Couldn't read interface count";
        my ($if_count) = unpack "n", $buffer;
        $self->handle_begin_interfaces($if_count);
        if ($if_count) {
            $io->read($buffer, 2 * $if_count) == 2 * $if_count or croak "Couldn't read list of interfaces";
            my @ifs = unpack "n*", $buffer;
            for my $if (@ifs) {
                my $name_index = $constant_pool[$if]->[0];
                $self->handle_interface($if, $name_index, $constant_pool[$name_index]->[0]);
            }
            $self->handle_end_interfaces($if_count);
        }
    }
    
    # Class fields
    {
        $io->read($buffer, 2) == 2 or croak "Couldn't read field count";
        my ($field_count) = unpack "n", $buffer;
        $self->handle_begin_fields($field_count);
        while ($field_count-- > 0) {
            $io->read($buffer, 8) == 8 or croak "Couldn't read field info";
            my ($access_flags, $name_index, $descriptor_index, $attributes_count) = unpack "n4", $buffer;
            my @attributes = _read_attributes($io, \@constant_pool, $attributes_count);
            $self->handle_field(
                $access_flags, 
                $name_index, $constant_pool[$name_index]->[0], 
                $descriptor_index, $constant_pool[$descriptor_index]->[0], 
                \@attributes
            );
        }
        $self->handle_end_fields();
    }
    
    # Class methods
    {
        $io->read($buffer, 2) == 2 or croak "Couldn't read field count";
        my ($method_count) = unpack "n", $buffer;
        $self->handle_begin_methods($method_count);
        while ($method_count-- > 0) {
            $io->read($buffer, 8) == 8 or croak "Couldn't read field info";
            my ($access_flags, $name_index, $descriptor_index, $attribute_count) = unpack "n4", $buffer;
            my @attributes = _read_attributes($io, \@constant_pool, $attribute_count);
            $self->handle_method(
                $access_flags, 
                $name_index, $constant_pool[$name_index]->[0], 
                $descriptor_index, $constant_pool[$descriptor_index]->[0], 
                \@attributes
            );
        }
        $self->handle_end_methods();
    }

    # Class attributes
    $io->read($buffer, 2) == 2 or croak "Couldn't read attribute count";
    my ($attribute_count) = unpack "n", $buffer;
    $self->handle_begin_attributes($attribute_count);
    my @attributes = _read_attributes($io, \@constant_pool, $attribute_count);
    $self->handle_attribute($_) for @attributes;
    $self->handle_end_attributes();
}

our %Attributes = (
    ConstantValue   => \&_read_ConstantValue_attribute,
    Code            => \&_read_Code_attribute,
    Exceptions      => \&_read_Exceptions_attribute,
);

sub _read_attributes {
    my ($io, $cp, $count) = @_;
    
    my ($buffer, @attributes);
    while ($count-- > 0) {
        $io->read($buffer, 6) == 6 or croak "Couldn't read attriute info header";
        my ($attribute_name_index, $len) = unpack "nN", $buffer;
        my $type = $cp->[$attribute_name_index]->[0];
        if (exists $Attributes{$type}) {
            push @attributes, {$Attributes{$type}->($io, $cp), type => $type};
        }
        else {
            my $data;
            $io->read($data, $len) == $len or croak "Couldn't read attribute data";
            push @attributes, {type => $type, data => $data};
        }
    }
    
    return @attributes;
}

sub _read_ConstantValue_attribute {
    my ($io, $cp) = @_;
    my $ix = _read_short $io;
    return (
        cp_index => $ix, 
        value => $cp->[$ix]->[0],
    );
}

sub _read_Code_attribute {
    my ($io, $cp) = @_;

    my $max_stack = _read_short $io;
    my $max_locals = _read_short $io;
    my $code_length = _read_int $io;
    my $code = _read_bytes $io, $code_length, "instructions";
    my $ex_table_length = _read_short $io;
    my @ex_table;
    for (1..$ex_table_length) {
        my $ex = {};
        @{$ex}{start_pc end_pc handler_pc catch_type_index} = unpack "nnnn", _read_bytes $io, 8, "exception table entry";
        $ex->{catch_type} = $cp->[$ex->{catch_type_index}]->[0];
        push @ex_table, $ex;
    }
    
    my $attribute_count = _read_short $io;
    my @attributes = _read_attributes $io, $cp, $attribute_count;
    
    return (
        max_stack => $max_stack, max_locals => $max_locals,
        code => $code,
        exception_table => \@ex_table,
        attributes => \@attributes,
    );
}

sub _read_Exceptions_attribute {
    my ($io, $cp) = @_;
    
    my $num_exceptions = _read_short $io;
    my @exceptions;
    if ($num_exceptions) {
        @exceptions = unpack "n$num_exceptions", _read_bytes $io, $num_exceptions * 2, " exception_index_table";
        @exceptions = map +{ index => $_, type => $cp->[$cp->[$_]->[0]]->[0] }, @exceptions;
    }
    
    return (
        exceptions => \@exceptions,
    );
}

sub handle_magic { 1; }
sub handle_version { 1; }

sub handle_begin_constant_pool { 1; }
sub handle_constant_pool_entry { 1; }
sub handle_end_constant_pool { 1; }

sub handle_class_access_flags { 1; }
sub handle_this_class { 1; }
sub handle_super_class { 1; }

sub handle_begin_interfaces { 1; }
sub handle_interface { 1; }
sub handle_end_interfaces { 1; }

sub handle_begin_fields { 1; }
sub handle_field { 1; }
sub handle_end_fields { 1; }

sub handle_begin_methods { 1; }
sub handle_method { 1; }
sub handle_end_methods { 1; }

sub handle_begin_attributes { 1; }
sub handle_attribute { 1; }
sub handle_end_attributes { 1; }

1;
=pod

=head1 NAME

JVM::BCE::Reader - Event generating CLASS file reader

=head1 SYNOPSIS

  use parent qw(JVM::BCE::Reader);
  
  sub handle_constant_pool_entry {
    my ($self, $index, $type, @data) = @_;
  }

=head1 EVENTS

=over 4

=item handle_magic ( $self, $magic )

=item handle_version ( $self, $version )

=item handle_begin_constant_pool ( $self, $item_count )

=item handle_constnat_pool_entry ( $self, $index, $type, @data )

=item handle_class_access_flags ( $self, $access_flags )

=item handle_this_class ( $self, $index, $class_info_entry, $name )

=item handle_super_class ( $self, $index, $class_info_entry, $name )

=back

=cut
