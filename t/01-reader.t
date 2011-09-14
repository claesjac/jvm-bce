#!/usr/bin/perl

package t::JVM::BCE::Reader;

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Test::More qw(no_plan);
use Test::Exception;

BEGIN { use_ok("JVM::BCE::Reader"); }

our @ISA = qw(JVM::BCE::Reader);

throws_ok {
    t::JVM::BCE::Reader->read(__FILE__);
} qr/Expected magic '0xcafebabe' but got '0x23212f75'/;

my $class = t::JVM::BCE::Reader->read('t/data/Foo.class');

{
    my $magic;
    sub handle_magic {
        $magic = pop;
    }
    is($magic, 0xcafebabe);
}

{
    my $version;
    sub handle_version {
        $version = pop;
    }
    is($version, "50.0");
}

{
    my $cp_count;
    sub handle_begin_constant_pool {
        $cp_count = pop;
    }
    is($cp_count, 28);
    
    my $cp_calls;
    sub handle_constant_pool_entry {
        $cp_calls++;
    }
    is($cp_calls, 28);
}

{
    my ($access_flags);
    sub handle_class_access_flags {
        $access_flags = pop;
    }
    is($access_flags, 0x21);
}

{
    my ($index, $class_info, $name);
    sub handle_this_class {
        (undef, $index, $class_info, $name) = @_;
    }
    is($index, 5);
    is_deeply($class_info, [21]);
    is($name, "Foo");
}

{
    my ($index, $class_info, $name);
    sub handle_super_class {
        (undef, $index, $class_info, $name) = @_;
    }
    is($index, 6);
    is_deeply($class_info, [22]);
    is($name, "java/lang/Object");
}