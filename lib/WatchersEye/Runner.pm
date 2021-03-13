package WatchersEye::Runner;
use Moo;
use utf8;
use WatchersEye::Collector;
use WatchersEye::Publisher;
use YAML::XS 'LoadFile';

has settings => (
    is => 'ro',
    default => sub { LoadFile "./settings.yml" }
);
has publisher => (
    is => 'ro',
    lazy => 1,
    default => sub { WatchersEye::Publisher->new(
        publishers => shift->settings->{publishers}
    ) }
);

sub run {
    my $self = shift;

    for my $target (@{$self->settings->{targets}}) {
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
