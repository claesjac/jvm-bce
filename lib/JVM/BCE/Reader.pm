package JVM::BCE::Reader;

use strict;
use warnings;

use Carp qw(croak);

sub _read_short {
    my $io = shift;
    my $buffer;
    $io->read($buffer, 2) == 2 or croak "Can't read short";
    return unpack "n", $buffer;
}

sub _read_int {
    my $io = shift;
    my $buffer;
    $io->read($buffer, 4) == 4 or croak "Can't read long";
    return unpack "N", $buffer;
}

sub _read_long {
    my $io = shift;
    my $buffer;
    $io->read($buffer, 8) == 8 or croak "Can't read long";
    my ($high, $low) = unpack "NN", $buffer;
    my $value = ($high * (2**32)) + $low;    
    return $value;
}

sub _read_float {
    my $io = shift;
    my $buffer;
    $io->read($buffer, 4) == 4 or croak "Can't read long";
    return unpack "f>", $buffer;
}

sub _read_double {
    my $io = shift;
    my $buffer;
    $io->read($buffer, 8) == 8 or croak "Can't read long";
    return unpack "d>", $buffer;
}

sub _read_short_short {
    my $io = shift;
    return (_read_short($io), _read_short($io));
}

sub _read_reference {
    my $io = shift;
    my $buffer;
    $io->read($buffer, 3) == 3 or croak "Can't read reference";
    return unpack "Cn", $buffer;
}

sub _read_utf8 {
    my $io = shift;
    my $len = _read_short($io);
    my $buffer;
    $io->read($buffer, $len) == $len or croak "Failed to read $len bytes of utf8 data";

    require utf8;

    my ($str) = unpack "a*", $buffer;
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
    {
        $io->read($buffer, 2) == 2 or croak "Couldn't read constant pool count";
        my ($cp_count) = unpack "n", $buffer;
        $self->handle_begin_constant_pool($cp_count - 1);
    
        my $ix = 0;
        while ($cp_count-- > 1) {
            $io->read($buffer, 1) == 1 or croak "Couldn't read constant pool item tag";
            my ($tag) = unpack "C", $buffer;
            croak "Unknown constant pool tag ${tag}" unless exists $CP_Reader{$tag};
            my ($ix_offset, @entry) = $CP_Reader{$tag}->($io);        
            $self->handle_constant_pool_entry($ix, $CP_TagName{$tag}, @entry);
            $ix += $ix_offset;
        }
    }
}

sub handle_magic { 1; }
sub handle_version { 1; }
sub handle_begin_constant_pool { 1; }
sub handle_constant_pool_entry { 1; }

1;