#!/usr/bin/perl
# 
# ping.pl
# 
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/08/2009 21:59:13 PST 21:59:13

use strict;
use warnings;
use Test::More tests => 1;
use Test::System::Test;
use Data::Dumper;

print Dumper(get_nodes());
print Dumper(get_param('ping_count'));
is(1, 1, 'Test: 1');

