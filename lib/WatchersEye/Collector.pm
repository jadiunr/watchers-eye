package WatchersEye::Collector;
use Moo;
use utf8;
use WatchersEye::Collector::Mastodon;
use WatchersEye::Collector::Mastodon::REST;
use WatchersEye::Collector::Twitter;
use WatchersEye::Collector::Misskey;

has target => (is => 'ro');
has cb => (is => 'ro');

sub run {
    my $self = shift;
    my $collector;

    if ($self->target->{kind} eq 'mastodon') {
        $collector = WatchersEye::Collector::Mastodon->new(
            target => $self->target,
            cb => $self->cb
        );
    } elsif ($self->target->{kind} eq 'mastodon_rest') {
        $collector = WatchersEye::Collector::Mastodon::REST->new(
            target => $self->target,
            cb => $self->cb
        );
    } elsif ($self->target->{kind} eq 'twitter') {
        $collector = WatchersEye::Collector::Twitter->new(
            target => $self->target,
            cb => $self->cb
        );
    } elsif ($self->target->{kind} eq 'misskey') {
        $collector = WatchersEye::Collector::Misskey->new(
            target => $self->target,
            cb => $self->cb
        );
    } else {
        die "Unsupported service kind.\n";
    }

    return $collector->run;
}

1;
