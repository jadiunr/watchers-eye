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
use Scalar::Util qw/looks_like_number/;

has publisher => (
    is => 'ro',
    lazy => 1,
    default => sub { WatchersEye::Publisher->new(
        publishers => $Config->{publishers}
    ) }
);

sub run {
    my $self = shift;

    my $collector_processes = sub {
        if ($Config->{collector_processes} eq 'auto') {
            chomp(my $nproc = `nproc --all`);
            return $nproc;
        } elsif (looks_like_number($Config->{collector_processes})) {
            return $Config->{collector_processes};
        } else {
            die "collector_processes in global.yml: Not an integer";
        }
    }->();
    my $pm = Parallel::ForkManager->new($collector_processes);
    my $targets = clone($Config->{targets});
    my $num_targets = scalar(@$targets);
    my $num_targets_per_process = ceil($num_targets / $collector_processes);

    while(my $targets_per_process = [splice @$targets, 0, $num_targets_per_process]) {
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
        AnyEvent->condvar->recv;
        $pm->finish;
    }

    $pm->wait_all_children;
}

1;
