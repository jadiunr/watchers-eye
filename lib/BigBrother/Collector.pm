package BigBrother::Collector;
use Moo;
use utf8;
use BigBrother::Collector::Mastodon;
use BigBrother::Collector::Twitter;
use BigBrother::Collector::Misskey;

has target => (is => 'ro');
has cb => (is => 'ro');

sub run {
    my $self = shift;
    my $collector;

    if ($self->target->{kind} eq 'mastodon') {
        $collector = BigBrother::Collector::Mastodon->new(
            target => $self->target,
            cb => $self->cb
        );
    } elsif ($self->target->{kind} eq 'twitter') {
        $collector = BigBrother::Collector::Twitter->new(
            target => $self->target,
            cb => $self->cb
        );
    } elsif ($self->target->{kind} eq 'misskey') {
        $collector = BigBrother::Collector::Misskey->new(
            target => $self->target,
            cb => $self->cb
        );
    } else {
        die "Unsupported service kind.\n";
    }

    return $collector->run;
}

1;
