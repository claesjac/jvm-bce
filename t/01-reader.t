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
    is($cp_count, 42);
    
    my $cp_calls;
    sub handle_constant_pool_entry {
        $cp_calls++;
    }
    is($cp_calls, 42);
    
    my $cp_end;
    sub handle_end_constant_pool {
        $cp_end++;
    }
    is($cp_end, 1);
}

{
    my $access_flags;
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
    is_deeply($class_info, [33]);
    is($name, "Foo");
}

{
    my ($index, $class_info, $name);
    sub handle_super_class {
        (undef, $index, $class_info, $name) = @_;
    }
    is($index, 6);
    is_deeply($class_info, [34]);
    is($name, "java/lang/Object");
}

{
    my $if_count;
    sub handle_begin_interfaces {
        $if_count = pop;
    }
    is($if_count, 2);
    
    my @ifs;
    sub handle_interface {
        shift;
        push @ifs, [@_];
    }
    is (scalar @ifs, 2);
    is_deeply (shift @ifs, [7, 35, 'java/lang/Comparable']);
    is_deeply (shift @ifs, [8, 36, 'java/lang/Runnable']);
    
}

{
    my $field_count;
    sub handle_begin_fields {
        $field_count = pop;
    }
    is($field_count, 2);
    
    my @fields;
    sub handle_field {
        shift;
        push @fields, [@_];
    }
    is (scalar @fields, 2);
    is_deeply (shift @fields, [0, 9, 'bar', 10, 'I', []]);
    is_deeply (shift @fields, [9, 11, 'quax', 12, 'Ljava/lang/Thread;', [[13, 'Deprecated', ''], [14, 'RuntimeVisibleAnnotations', "\0\1\0\17\0\0"]]]);    
}

{
    my $method_count;
    sub handle_begin_methods {
        $method_count = pop;
    }
    is($method_count, 4);
    
    my @methods;
    sub handle_method {
        shift;
        pop;
        push @methods, [@_];
    }
    is (scalar @methods, 4);
    is_deeply (shift @methods, [1, 16, '<init>', 17, '()V']);
    is_deeply (shift @methods, [1, 20, 'run', 17, '()V']);    
}

