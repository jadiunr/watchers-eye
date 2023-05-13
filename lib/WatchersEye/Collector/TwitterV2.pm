package WatchersEye::Collector::TwitterV2;
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
        api_version         => '2',
        api_ext             => '',
        consumer_key        => $self->target->{credentials}{consumer_key},
        consumer_secret     => $self->target->{credentials}{consumer_secret},
        access_token        => $self->target->{credentials}{access_token},
        access_token_secret => $self->target->{credentials}{access_token_secret}
    );
});
has timer => (is => 'rw');
has initialized => (is => 'rw', default => 0);

sub run {
    my $self = shift;
    my $cv = AnyEvent->condvar;

    say $self->target->{label}. ": Twitter v2 fetch interval=". $self->interval;

    my $t = AnyEvent->timer(
        after => $self->interval,
        interval => $self->interval,
        cb => sub {
            eval {

                if ($self->since_id) {
                    $self->statuses($self->twitter->get('users/'. $self->target->{account_id}. '/tweets?expansions=author_id,referenced_tweets.id,attachments.media_keys,referenced_tweets.id.author_id&media.fields=url,variants&user.fields=profile_image_url,protected&max_results=20&since_id='. $self->since_id));
                } else {
                    $self->statuses($self->twitter->get('users/'. $self->target->{account_id}. '/tweets?expansions=author_id,referenced_tweets.id,attachments.media_keys,referenced_tweets.id.author_id&media.fields=url,variants&user.fields=profile_image_url,protected&max_results=20'));
                }

                unless ($self->initialized) {
                    $self->since_id($self->statuses->{data}[0]{id});
                    $self->initialized(1);
                    say $self->target->{label}. ': Initialized';
                    return;
                }

                if ($self->statuses->{data}) {
                    for my $status (@{$self->statuses->{data}}) {
                        my $media_attachments = [];
                        my $media_keys = $status->{attachments}{media_keys};
                        if ($media_keys) {
                            for my $media_key (@$media_keys) {
                                my ($media_attachment) = grep { $media_key eq $_->{media_key} } @{ $self->statuses->{includes}{media} };
                                next unless $media_attachment;
                                if ($media_attachment->{type} eq 'photo') {
                                    push(@$media_attachments, { url => $media_attachment->{url} });
                                } elsif ($media_attachment->{type} eq 'video') {
                                    my $variants = $media_attachment->{variants};
                                    for (@$variants) { $_->{bit_rate} = 0 unless $_->{bit_rate} }
                                    my $url = (sort { $b->{bit_rate} <=> $a->{bit_rate} } @$variants)[0]{url};
                                    $url =~ s/\?.+//;
                                    push(@$media_attachments, { url => $url });
                                }
                            }
                        }

                        if ($status->{referenced_tweets}) {
                            for my $referenced_tweet (@{ $status->{referenced_tweets} }) {
                                if ($referenced_tweet->{type} eq 'replied_to') {
                                    my ($reply) = grep { $referenced_tweet->{id} eq $_->{id} } @{ $self->statuses->{includes}{tweets} };
                                    $status->{text} .= "\n\nIn reply to https://twitter.com/". $reply->{author_id}.  "/status/". $reply->{id}. "\n";
                                }
                            }
                        }

                        my $user = grep { $status->{author_id} eq $_->{id} } @{ $self->statuses->{includes}{users} };
                        $status->{user}{name} = $user->{name};
                        $status->{user}{screen_name} = $user->{username};
                        $status->{user}{profile_image_url_https} = $user->{profile_image_url};
                        $status->{user}{protected} = $user->{protected};

                        $self->cb->({
                            display_name      => $status->{user}{name},
                            acct              => $status->{user}{screen_name}.'@twitter.com',
                            avatar_url        => $self->target->{avatar_url} || $status->{user}{profile_image_url_https},
                            content           => $status->{text},
                            visibility        => $status->{user}{protected} ? 'private' : 'public',
                            media_attachments => $media_attachments,
                        });
                    }
                    $self->since_id($self->statuses->{data}[0]{id});
                }
            };
            say $self->target->{label}. ': '. $@ if $@;
        }
    );

    $self->timer($t);

    return $cv;
}

1;
