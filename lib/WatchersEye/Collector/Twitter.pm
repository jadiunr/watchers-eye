package WatchersEye::Collector::Twitter;
use Moo;
use utf8;
use AnyEvent;
use Twitter::API;
use WatchersEye::Publisher::Discord;
use JSON::XS;
use Encode 'encode_utf8';
use feature 'say';

has target => (is => 'ro');
has cb => (is => 'ro');
has statuses => (is => 'rw');
has since_id => (is => 'rw');
has twitter => (is => 'ro', lazy => 1, default => sub {
    my $self = shift;
    Twitter::API->new_with_traits(
        traits              => 'Enchilada',
        consumer_key        => $self->target->{credentials}{consumer_key},
        consumer_secret     => $self->target->{credentials}{consumer_secret},
        access_token        => $self->target->{credentials}{access_token},
        access_token_secret => $self->target->{credentials}{access_token_secret}
    );
});

sub run {
    my $self = shift;

    $self->statuses($self->twitter->user_timeline({
        user_id => $self->target->{account_id}
    }));
    $self->since_id($self->statuses->[0]{id});

    my $cv = AnyEvent->condvar;
    our $t; $t = AnyEvent->timer(
        after => 0,
        interval => 5,
        cb => sub {
            $self->statuses($self->twitter->user_timeline({
                user_id => $self->target->{account_id},
                since_id => $self->since_id
            }));

            if (@{$self->statuses}) {
                for my $status (@{$self->statuses}) {
                    my $media_attachments = [map { +{ url => $_->{media_url_https} } } @{$status->{extended_entities}{media}}];
                    $self->cb->({
                        display_name      => $status->{user}{name},
                        acct              => $status->{user}{screen_name}.'@twitter.com',
                        avatar_url        => $status->{user}{profile_image_url_https},
                        content           => $status->{text},
                        media_attachments => $media_attachments
                    });
                }
                $self->since_id($self->statuses->[0]{id});
            }
        }
    );

    return $cv;
}

1;
