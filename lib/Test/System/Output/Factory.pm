#
# Test::System::Output::Factory
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 11/08/2009 15:20:11 PST 15:20:11
package Test::System::Output::Factory;

use strict;
use warnings;
use Class::Factory;
use base qw(Class::Factory);

sub new {
    my ($pkg, $type, @params) = @_;
    my $class = $pkg->get_factory_class($type);
    return undef unless ($class);
    my $self = "$class"->new(@params);
    return $self;
}

__PACKAGE__->register_factory_type(html => 'TAP::Formatter::HTML');
__PACKAGE__->register_factory_type(console => 'TAP::Formatter::Console');
1;

