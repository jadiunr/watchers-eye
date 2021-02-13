package BigBrother::Runner;
use Moo;
use BigBrother::Collector;
use YAML::XS 'LoadFile';

has target_label => (is => 'ro');
has settings => (
    is => 'ro',
    default => sub { LoadFile "./settings.yml" }
);

sub run {
    my $self = shift;
    my $collector = BigBrother::Collector->new(
        settings => $self->settings,
        target_label => $self->target_label
    );
    $collector->run;
}

1;
