package WatchersEye::Runner;
use Moo;
use utf8;
use WatchersEye::Config;
use WatchersEye::Collector;
use WatchersEye::Publisher;
use YAML::XS 'LoadFile';
use Parallel::ForkManager;

has publisher => (
    is => 'ro',
    lazy => 1,
    default => sub { WatchersEye::Publisher->new(
        publishers => $Config->{publishers}
    ) }
);

sub run {
    my $self = shift;

    my $pm = Parallel::ForkManager->new(4);
    for my $target (@{$Config->{targets}}) {
        $pm->start and next;
        WatchersEye::Collector->new(
            target => $target,
            cb => sub {
                my $status = shift;
                $self->publisher->publish($target, $status);
            }
        )->run;
        $pm->finish;
    }

    AnyEvent->condvar->recv;
}

1;
