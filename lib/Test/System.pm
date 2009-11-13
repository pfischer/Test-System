#
# Test::System
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/07/2009 17:36:17 PST 17:36:17
package Test::System;

=head1 NAME

Test::System - Test suite oriented for testing a *system*

=head1 SYNOPSIS

    use Test::System;

    my $suite = Test::System->new(
            format => 'consoletable',
            nodes => 'example.com',
            test_groups => '~/code/my/system/tests.yaml'
            );
    $hung->runtests;

=head1 DESCRIPTION

Loads and runs the available tests cases located in the namespace of
Seco::Insanity::Tests. User can specify if only one or a group of tests cases
should be run.

=head1 AUTHOR
 
Pablo Fischer (pablo@pablo.com.mx).

=head1 COPYRIGHT
 
Copyright (C) 2009 by Pablo Fischer
 
This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
use 5.006;

use Moose; # it turns strict and warnings
use File::Basename qw(dirname);
use YAML::Syck;
use Test::System::Output::Factory;
use TAP::Harness;
use UNIVERSAL qw(isa);
use Data::Dumper;

our $VERSION = '0.02';

=head1 Attributes

Test::System exports a number of attributes that some only have read only
access and others allow write access.

=over 6

=item B<test_groups>

YAML filename of where a list of available tests are. This is not required but
can be useful if you want to group tests (like I<hardware.yaml>, I<net.yaml>,
etc). Comes also handy when user does not provide a list of tests to execute,
so all the tests listed in this file are executed.

An example of a YAML file:

    ping:
        description: Test the ping and do foo and make bar
        code: test/foo.pl
    cpu:
        description: Test the CPU of nodes
        code: test/cpu.pl

=cut
has 'test_groups' => (
        is => 'rw',
        isa => 'Str',
        trigger => \&_read_test_groups_file
        );

=item B<available_tests>

Is a read only attribute that contains a list of all available tests found in
the YAML file provided by tests_yaml.

=cut
has 'available_tests' => (
        is => 'ro',
        isa => 'ArrayRef[Str]',
        );

=item B<nodes>

Is an attribute that can be represented as a string (like a hostname) or as a
list (where each item will be a node/hostname). This attribute has write access
and is where the tests are going to be executed to.

=cut
has 'nodes' => (
        is => 'rw',
        isa => 'Any',
        trigger => \&_verify_nodes_datatype
        );

=item B<format>

A write access string that has the format of how the tests should be presented,
please refer to the modules available under Test::System::Output

=cut
has 'format' => (
        is => 'rw',
        isa => 'Str',
        default => 'console',
        trigger => \&_verify_format
        );

=item B<available_formats>

A list of available formats, read only.

=cut
has 'available_formats' => (
        is => 'ro',
        isa => => 'HashRef',
        default => \&_generate_output_types_hash
        );

=item B<custom_factory>

If you want to use your own Factory for creating your output you can set this
to your class name (B<NOT the object>).

=cut
has 'custom_factory' => (
        is => 'rw',
        isa => 'Str',
        trigger => \&_generate_output_types_hash
        );

=item B<parameters>

An attribute with write access permission. This attribute will transform all
the items of this hash to environment variables.

The use of this attribute is very handy if you want to provide some additional
data for your tests and since the tests are run in separate forks with
Test::Harness then the only possible way to keep them is to make them available
through the environment (C<%ENV> hash).

Please be warned that only scalars are stored in environment variables, those
that are an array will be converted to CSV values while the rest of the data
types will be lost.

In your tests if you want to use any of these parameters they will be available
through the environment variables with a prefix of: I<TEST_SYSTEM_>.

=cut
has 'parameters' => (
        is => 'rw',
        isa => 'HashRef[Str]',
        );

=back

=head1 Methods

=over 4

=item B<runtests( @tests , %options )>

It will run a group of given test cases, however if no list is given or is
empty then all the available cases will be run.

The C<%options> is a hash of options that will be passed to the B<TAP::Harness>
object, some useful parameters are:

=over 4

=item * verbosity

By default we mute everything with C<-9>.

=item * color

If you want the output (in console) to have color

=item * formatter

Although we use B<Test::System::Output::Factory> to offer a set of formatters
you can provide your own formatter object.

=item * jobs

If you have many tests you probably want to increment this value (that defaults
to C<1>) so other tests can be run at the same time.

=back

=cut
sub runtests {
    my ($self, $tests, $options) = @_;
    my @tests_to_run;
    if (isa(\$tests, 'ARRAY')) {
        @tests_to_run = $tests;
    } elsif (isa(\$tests, 'SCALAR') and $tests =~ qr/\S+.yaml$/) {
        @tests_to_run = $self->get_tests_from_test_plan($tests);
    }

    if (!@tests_to_run and $self->yaml_file) {
        @tests_to_run = keys(%{$self->available_tests});
    }
    if (!$self->nodes) {
        die "No nodes were specified";
    }
    # No duplicate tests and build the module name
    my (%seen, @test_files);
    foreach (@tests_to_run) {
        if (!$seen{$_}++) {
            # Does the test exist?
            my ($code, $description) = ($_, $_);
            if (defined $self->available_tests) {
                if (defined $self->available_tests->{$_}) {
                    if (defined $self->available_tests->{$_}->{'code'}) {
                        $code = $self->available_tests->{$_}->{'code'};
                    }
                    if (defined $self->available_tests->{$_}->{'description'}) {
                        $description = $self->available_tests->{$_}->{'description'};
                    }
                }
                if (!-f $code) {
                    warn "$_ was not found inside the test groups file, skipping";
                    next;
                }
            } else {
                if (!-f $_) {
                    warn "$_ was not found on a test YAML file or as a file, skipping";
                    next;
                }
            }
            if ($code and $description) {
                push(@test_files, [ $code, $description ]);
            }
        }
    }
    $self->prepare_environment();
    my $factory_class = 'Test::System::Output::Factory';
    if ($self->custom_factory) {
        $factory_class = $self->custom_factory;
    }
    my $formatter_class = "$factory_class"->get_registered_class(
            $self->format
            );
    if (!defined $options->{'formatter_class'} && !defined $options->{'formatter'}) {
        $options->{'formatter_class'} = $formatter_class;
    }
    $options->{'merge'} = 0 unless defined $options->{'merge'};
    my $verbosity = -9;
    if (defined $options->{'verbosity'}) {
        $verbosity = $options->{'verbosity'};
        delete $options->{'verbosity'};
    }
    my @lib = @INC;
    if (defined $options->{'lib'} && ref $options->{'lib'} eq 'ARRAY') {
        foreach (@$options->{'lib'}) {
            push(@lib, $_);
        }
    }
    $options->{'lib'} = \@lib;
    my $harness = TAP::Harness->new($options);
    $harness->formatter->verbosity($verbosity);
    $harness->runtests(@test_files);
    $self->clean_environment();
    return 1;
}

=item B<prepare_environment ()>

Prepares the environment by settings the needed environment values so they can
be used later by the tests

=cut
sub prepare_environment {
    my ($self) = @_;

    # Nodes are stored under the TEST_SYSTEM_NODES environment key
    $ENV{TEST_SYSTEM_NODES} = $self->nodes;
    if ($self->parameters) {
        if (ref $self->parameters eq 'HASH') {
            foreach my $k (keys %{$self->parameters}) {
                my $value = $self->parameters->{$k};
                $k = uc $k;
                if (!defined $ENV{'TEST_SYSTEM_' . $k}) {
                    if (isa(\$value, 'SCALAR')) {
                        $ENV{'TEST_SYSTEM_' . $k} = $value;
                    } elsif (isa(\$value, 'ARRAY')) {
                        $ENV{'TEST_SYSTEM_' . $k} = join(',', $value);
                    }
                }
            }
        }
    }
}

=item B<clean_environment ()>

Cleans/deletes all the environment variables that match I<TEST_SYSTEM_*>

=cut
sub clean_environment {
    my ($self) = @_;

    my %environment_vars = %ENV;
    foreach my $k (%environment_vars) {
        if ($k =~ /^TEST_SYSTEM_/) {
            delete $ENV{$k};
        }
    }
}

=item B<get_tests_from_test_plan ( $yaml_file,
        $do_not_fill_parameters, 
        $do_not_fill_nodes ) >

Reads the given tests yaml file (I<$yaml_file>). This YAML file should have at
least a list of tests (in the form of a hash) and optionally can also have
parameters the tests should contain.

Although this method is used mostly internally there's the option to call it
as any other method B<Test::System> offers.

By default it will fill the parameters of your B<Test::System> instance but by
passing I<$do_not_fill_parameters> (second parameter) as true or something
that Perl understands as true then it will skip the part. This should be
presented as a hash in YAML syntax.

The above appleis for I<$do_not_fill_nodes> (third parameter). This should be
presented as an array in YAML syntax.

Once the file is read it will return an array of all the tests

An example of a YAML test plan file can be found inside the I<examples>
directory or:

    tests:
        - ping
        - cpu
        - memory
    parameters:
        foo: bar
        bar: zoo
    nodes:
        - pablo.com.mx
        - example.com

=back

=cut
sub get_tests_from_test_plan {
    my ($self, $yaml_file, $do_not_fill_parameters, $do_not_fill_nodes) = @_;

    if (!-f $yaml_file) {
        warn "YAML file ($yaml_file) does not exist, skipping the read";
        return;
    }

    my @tests;
    my $data = LoadFile($yaml_file);
    if (!defined $data->{'tests'}) {
        warn "YAML file ($yaml_file) does not have any tests to execute";
        return;
    } else {
        @tests = @{$data->{'tests'}};
    }
    if (!$do_not_fill_parameters) {
        if ($data->{'parameters'}) {
            $self->parameters($data->{'parameters'});
        }
    }

    if (!$do_not_fill_nodes) {
        if ($data->{'nodes'}) {
            $self->nodes($data->{'nodes'});
        }
    }
    return @tests;
}

################################# Triggers ##################################
# Trigger for test_dir, when test_dir gets modified we look for all tests
# available in the given directory and so on we populate/fill the tests list
# attribute
sub _read_test_groups_file {
    my ($self, $yaml_file) = @_;
    
    if (!-f $yaml_file) {
        confess "The YAML file ($yaml_file) does not exist";
    }

    $self->{tests_yaml} = $yaml_file;
    my $testdir = dirname($yaml_file);

    my $tests = LoadFile($yaml_file);
    foreach my $test (keys %$tests) {
        if (defined $tests->{$test}->{'code'}) {
            my $code = $tests->{$test}->{'code'};
            if (!-f $code) {
                $tests->{$test}->{'code'} = $testdir . '/' . $code;
            }
        }
    }
    $self->{available_tests} = $tests;
}

# Trigger for nodes, when nodes gets modified we don't really know if its
# a string or a list (and this is because we accept both) so we should make sure
# of what we get and validate it.
sub _verify_nodes_datatype {
    my ($self, $nodes) = @_;

    if (ref $nodes eq 'ARRAY') {
        $self->{nodes} = join(',', @$nodes);
    } else {
        $self->{nodes} = $nodes;
    }
}

# Trigger for format, when format gets modified we want to make sure the format
# is valid
sub _verify_format {
    my ($self, $format) = @_;

    if (!defined $self->available_formats->{$format}) {
        confess "The format you provided ($format) is not valid";
    }

    $self->{format} = $format;
}

# Generates the output type hash reference by checking the registered factory
# types of Test::System::Output::Factory or in the custom Factory class
sub _generate_output_types_hash {
    my ($self, $new_factory) = @_;

    if (!$new_factory) {
        $new_factory = 'Test::System::Output::Factory';
    } else {
        $self->{custom_factory} = $new_factory;
    }
    my @registered_types = "$new_factory"->get_registered_types;

    my %hash;
    foreach (@registered_types) {
        $hash{$_} = 1;
    }
    return \%hash;
}

1;

