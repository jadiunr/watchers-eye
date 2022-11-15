package WatchersEye::Collector::Twitter;
use Moo;
use utf8;
use AnyEvent;
use Twitter::API;
use JSON::XS;
use Encode 'encode_utf8';
use feature 'say';
use WatchersEye::Config;

has target => (is => 'ro');
has cb => (is => 'ro');
has statuses => (is => 'rw');
has since_id => (is => 'rw');
has interval => (is => 'ro', lazy => 1, default => sub {
    my $self = shift;
    my $using_token_count = grep {defined($_->{credentials}{access_token}) and $self->target->{credentials}{access_token} eq $_->{credentials}{access_token}} @{$Config->{targets}};
    return $using_token_count;
});
has twitter => (is => 'ro', lazy => 1, default => sub {
    my $self = shift;
    Twitter::API->new_with_traits(
        traits              => ['Enchilada', 'RateLimiting'],
        consumer_key        => $self->target->{credentials}{consumer_key},
        consumer_secret     => $self->target->{credentials}{consumer_secret},
        access_token        => $self->target->{credentials}{access_token},
        access_token_secret => $self->target->{credentials}{access_token_secret}
    );
});
has timer => (is => 'rw');

sub run {
    my $self = shift;
    my $cv = AnyEvent->condvar;

    $self->statuses($self->twitter->user_timeline({
        user_id => $self->target->{account_id},
        tweet_mode  => 'extended',
        include_ext_alt_text => 1,
        include_rts => $self->target->{include_rts} // 1,
    }));
    $self->since_id($self->statuses->[0]{id});

    say $self->target->{label}. ": Connected. interval=". $self->interval;

    my $t = AnyEvent->timer(
        after => $self->interval,
        interval => $self->interval,
        cb => sub {
            eval {
                $self->statuses($self->twitter->user_timeline({
                    user_id => $self->target->{account_id},
                    since_id => $self->since_id,
                    tweet_mode  => 'extended',
                    include_ext_alt_text => 1,
                    include_rts => $self->target->{include_rts} // 1,
                }));

                if (@{$self->statuses}) {
                    for my $status (@{$self->statuses}) {
                        my $media_attachments = [map { +{ url => $_->{media_url_https} } } @{$status->{extended_entities}{media}}];
                        my $reply_user = $status->{in_reply_to_user_id};
                        my $reply_status = $status->{in_reply_to_status_id};
                        $status->{full_text} .= ($reply_user and $reply_status)
                            ? "\n\nIn reply to https://twitter.com/$reply_user/status/$reply_status\n"
                            : "\n";
                        for my $media (@{$status->{extended_entities}{media}}) {
                            next unless $media->{ext_alt_text};
                            $status->{full_text} .= "\n\nALT: ". $media->{ext_alt_text}. "\n";
                        }

                        $self->cb->({
                            display_name      => $status->{user}{name},
                            acct              => $status->{user}{screen_name}.'@twitter.com',
                            avatar_url        => $self->target->{avatar_url} || $status->{user}{profile_image_url_https},
                            content           => $status->{full_text},
                            visibility        => $status->{user}{protected} ? 'private' : 'public',
                            media_attachments => $media_attachments,
                        });
                    }
                    $self->since_id($self->statuses->[0]{id});
                }
            };
            say $@ if $@;
        }
    );

    $self->timer($t);

    return $cv;
}

1;
