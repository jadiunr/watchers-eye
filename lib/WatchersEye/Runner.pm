package WatchersEye::Runner;
use Moo;
use utf8;
use POSIX;
use Clone 'clone';
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
    my $targets = clone($Config->{targets});
    my $num_targets = scalar(@$targets);
    my $num_targets_per_process = ceil($num_targets / 4);

    while(my $targets_per_process = splice @$targets, 0, $num_targets_per_process) {
        $pm->start and next;
        for my $target (@$targets_per_process) {
            WatchersEye::Collector->new(
                target => $target,
                cb => sub {
                    my $status = shift;
                    $self->publisher->publish($target, $status);
                },
            )->run;
        }
        $pm->finish;
    }

    AnyEvent->condvar->recv;
}

1;
