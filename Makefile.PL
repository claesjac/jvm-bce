use ExtUtils::MakeMaker;

use 5.010;

WriteMakefile(
    NAME            => 'JVM::BCE',
    VERSION_FROM    => 'lib/JVM/BCE.pm', # finds $VERSION
    ABSTRACT_FROM   => 'lib/JVM/BCE.pm', # retrieve abstract from module
    AUTHOR          => 'Claes Jakobsson <claesjac@cpan.org>',
);
