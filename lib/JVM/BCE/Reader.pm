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
        $self->handle_begin_constant_pool($cp_count - 1);
    
        my $ix = 1;
        while ($cp_count-- > 1) {
            $io->read($buffer, 1) == 1 or croak "Couldn't read constant pool item tag";
            my ($tag) = unpack "C", $buffer;
            croak "Unknown constant pool tag ${tag}" unless exists $CP_Reader{$tag};
            my ($ix_offset, @entry) = $CP_Reader{$tag}->($io);        
            $self->handle_constant_pool_entry($ix, $CP_TagName{$tag}, @entry);
            $constant_pool[$ix] = \@entry;
            $ix += $ix_offset;
        }
    }
    
    # Class declaration
    {
        $io->read($buffer, 2) == 2 or croak "Couldn't reed access flags";
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
    }
}

sub handle_magic { 1; }
sub handle_version { 1; }
sub handle_begin_constant_pool { 1; }
sub handle_constant_pool_entry { 1; }
sub handle_class_access_flags { 1; }
sub handle_this_class { 1; }
sub handle_super_class { 1; }

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
