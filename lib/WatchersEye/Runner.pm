package WatchersEye::Runner;
use Moo;
use utf8;
use WatchersEye::Config;
use WatchersEye::Collector;
use WatchersEye::Publisher;
use YAML::XS 'LoadFile';

has config => (
    is => 'ro',
    default => sub { WatchersEye::Config->load }
);

has publisher => (
    is => 'ro',
    lazy => 1,
    default => sub { WatchersEye::Publisher->new(
        publishers => shift->config->{publishers}
    ) }
);

sub run {
    my $self = shift;

    for my $target (@{$self->config->{targets}}) {
        WatchersEye::Collector->new(
            target => $target,
            cb => sub {
                my $status = shift;
                $self->publisher->publish($target, $status);
            }
        )->run;
    }

    AnyEvent->condvar->recv;
}

1;
