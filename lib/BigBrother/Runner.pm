package BigBrother::Runner;
use Moo;
use BigBrother::Collector;
use BigBrother::Publisher;
use YAML::XS 'LoadFile';

has settings => (
    is => 'ro',
    default => sub { LoadFile "./settings.yml" }
);
has publisher => (
    is => 'ro',
    lazy => 1,
    default => sub { BigBrother::Publisher->new(
        publishers => shift->settings->{publishers}
    ) }
);

sub run {
    my $self = shift;

    for my $target (@{$self->settings->{targets}}) {
        BigBrother::Collector->new(
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
