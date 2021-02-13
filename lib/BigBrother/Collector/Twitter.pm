package BigBrother::Collector::Twitter;
use Moo;
use AnyEvent;
use Twitter::API;
use BigBrother::Publisher::Discord;
use JSON::XS;
use Encode 'encode_utf8';
use feature 'say';

has settings => (is => 'ro');
has target => (is => 'ro');
has statuses => (is => 'rw');
has since_id => (is => 'rw');
has tw => (is => 'ro', lazy => 1, default => sub {
    my $self = shift;
    Twitter::API->new_with_traits(
        traits              => 'Enchilada',
        consumer_key        => $self->target->{credentials}{consumer_key},
        consumer_secret     => $self->target->{credentials}{consumer_secret},
        access_token        => $self->target->{credentials}{access_token},
        access_token_secret => $self->target->{credentials}{access_token_secret}
    );
});
has publisher => (is => 'ro', lazy => 1, default => sub {
    my $self = shift;
    BigBrother::Publisher::Discord->new(
        webhook_url => $self->settings->{publishers}{webhook_url}
    );
});

sub run {
    my $self = shift;

    $self->statuses($self->tw->user_timeline({
        user_id => $self->target->{account_id}
    }));
    $self->since_id($self->statuses->[0]{id});

    my $cv = AnyEvent->condvar;
    my $t; $t = AnyEvent->timer(
        after => 0,
        interval => 5,
        cb => sub {
            $self->statuses($self->tw->user_timeline({
                user_id => $self->target->{account_id},
                since_id => $self->since_id
            }));

            if (@{$self->statuses}) {
                for my $status (@{$self->statuses}) {
                    my $media_attachments = [map { +{ url => $_->{media_url_https} } } @{$status->{extended_entities}{media}}];
                    $self->publisher->publish({
                        display_name => $status->{user}{name},
                        screen_name  => $status->{user}{screen_name}.'@twitter.com',
                        avatar_url   => $status->{user}{profile_image_url_https},
                        content      => $status->{text},
                        media_attachments => $media_attachments
                    });
                }
                $self->since_id($self->statuses->[0]{id});
            }
        }
    );
    say 'Twitter Collector: Start.';
    $cv->recv;
}

1;
