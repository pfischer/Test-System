#!/usr/bin/perl
# 
# suite.pl
# 
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/08/2009 15:31:37 PST 15:31:37

use strict;
use warnings;
use Test::System;
use Test::System::Output::Factory;
use Data::Dumper;

my $suite = Test::System->new(
        nodes => ['example.com', 'pablo.com.mx'],
        test_groups => 'example/tests.yaml');

$suite->parameters(
        {
            'ping_count' => 5
        });
my $formatter = Test::System::Output::Factory->new('console',
        {
        verbosity => -3
        });
$suite->runtests(['ping', 'cpu'], {
        verbosity => -2,
        lib => ['foo']
#formatter => $formatter,
        });


