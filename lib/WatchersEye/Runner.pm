package WatchersEye::Runner;
use Moo;
use utf8;
use WatchersEye::Config;
use WatchersEye::Collector;
use WatchersEye::Publisher;
use YAML::XS 'LoadFile';

has publisher => (
    is => 'ro',
    lazy => 1,
    default => sub { WatchersEye::Publisher->new(
        publishers => $Config->{publishers}
    ) }
);

sub run {
    my $self = shift;

    for my $target (@{$Config->{targets}}) {
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
