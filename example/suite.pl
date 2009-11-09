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
        nodes => 'example.com',
        tests_yaml => 'example/tests.yaml');

my $formatter = Test::System::Output::Factory->new('html',
        {
        color => 1,
        });

$suite->runtests([], {
        formatter => $formatter,
        verbosity => 1,
        });
