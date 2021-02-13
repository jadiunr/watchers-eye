package BigBrother::Collector;
use Moo;
use BigBrother::Collector::Mastodon;
use BigBrother::Collector::Twitter;
use BigBrother::Collector::Misskey;

has settings => (is => 'ro');
has target_label => (is => 'ro');

sub run {
    my $self = shift;
    my $target = [grep {$_->{label} eq $self->target_label} @{$self->settings->{targets}}]->[0];
    my $collector;

    if ($target->{kind} eq 'mastodon') {
        $collector = BigBrother::Collector::Mastodon->new(
            settings => $self->settings,
            target => $target
        );
    } elsif ($target->{kind} eq 'twitter') {
        $collector = BigBrother::Collector::Twitter->new(
            settings => $self->settings,
            target => $target
        );
    } elsif ($target->{kind} eq 'misskey') {
        $collector = BigBrother::Collector::Misskey->new(
            settings => $self->settings,
            target => $target
        )
    } else {
        die "Unsupported service kind.\n";
    }

    $collector->run;
}

1;
