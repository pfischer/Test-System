#
# Test::System::Test
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/08/2009 14:03:24 PST 14:03:24
package Test::System::Test;

=head1 NAME

Test::System::Test - Desired parent class for all Test::System tests

=head1 DESCRIPTION

The purpose of this module is to provide the easiness of getting the list of
hostnames you want to test (if that is the case).

=cut

use Moose;
use Test::Class;
use Test::More;
use base qw(Test::Class);

=head2 Attributes

=over4

=item B<nodes>

A list of all the nodes/hosts that will be tested.

=over4
=cut
has 'nodes' => (
        is => 'ro',
        isa => => 'ArrayRef[Str]',
        default => \&generate_node_list
        );

# Fills the nodes attribute by checking the TEST_SYSTEM_NODES environment
# variable
sub generate_node_list {
    my $self = shift;
    my @node_list;
    if ($ENV{TEST_SYSTEM_NODES}) {
        @node_list = split(',', $ENV{TEST_SYSTEM_NODES});
    }
    # We don't like duplicated nodes..
    my %seen;
    my @unique = grep { ! $seen{$_}++ } @node_list;
    $self->{nodes} = \@unique;
}

######################### PRIVATE METHODS ############################
# Makes sure that before we start we have the needed information before
# starting the tests.
sub __setup_tests : Test(setup) {
    my $self = shift;

    if (!$self->nodes) {
        $self->SKIP_ALL("No nodes were given, nothing to test against");
    }
}

1;

