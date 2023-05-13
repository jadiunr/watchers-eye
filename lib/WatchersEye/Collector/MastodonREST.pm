package WatchersEye::Collector::MastodonREST;
use Moo;
use utf8;
use AnyEvent;
use JSON::XS;
use Furl;
use Encode 'encode_utf8';
use HTML::Entities 'decode_entities';
use feature 'say';
use WatchersEye::Config;

has target => (is => 'ro');
has cb => (is => 'ro');
has statuses => (is => 'rw');
has min_id => (is => 'rw');
has interval => (is => 'ro', lazy => 1, default => sub {
    my $self = shift;
    my $using_token_count = grep {defined($_->{credentials}{token}) and $self->target->{credentials}{token} eq $_->{credentials}{token}} @{$Config->{targets}};
    return $using_token_count * 5;
});
has timer => (is => 'rw');

sub run {
    my $self = shift;
    my $cv = AnyEvent->condvar;

    my %furl_args;
    $furl_args{agent} = 'Mozilla/5.0 (Windows NT 10.0; rv:68.0) Gecko/20100101 Firefox/68.0 ';
    $furl_args{headers} = ['Authorization' => "Bearer ". $self->target->{credentials}{token}] unless $self->target->{no_auth};
    $furl_args{proxy} = 'http://tor:8118' if $self->target->{use_tor};
    my $furl = Furl->new(%furl_args);
    my $endpoint = sprintf "https://%s/api/v1/accounts/%s/statuses?limit=40&exclude_replies=%s&exclude_reblogs=%s",
        $self->target->{domain}, $self->target->{account_id}, $self->target->{exclude_replies} ? 'true' : 'false', $self->target->{exclude_reblogs} ? 'true' : 'false';

    say $self->target->{label}. ": Connected. interval=". $self->interval;

    my $t = AnyEvent->timer(
        after => $self->interval,
        interval => $self->interval,
        cb => sub {
            eval {
                if ($self->min_id) {
                    $self->statuses(decode_json $furl->get($endpoint. "&min_id=". $self->min_id)->content);
                } else {
                    $self->statuses(decode_json $furl->get($endpoint)->content);
                    $self->min_id($self->statuses->[0]{id});
                    return;
                }

                if (@{$self->statuses}) {
                    for my $status (@{$self->statuses}) {
                        next if $status->{visibility} ne 'private' and $self->target->{private_only};
                        next if $status->{reblog} and $self->target->{exclude_reblogs};

                        $status->{content} =~ s/<(br|br \/|\/p)>/\n/g;
                        $status->{content} =~ s/<(".*?"|'.*?'|[^'"])*?>//g;
                        $status->{content} = decode_entities($status->{content});

                        if ($status->{spoiler_text}) {
                            $status->{content} = 'CW: '. $status->{spoiler_text}. "\n\n". $status->{content};
                        }

                        if ($status->{reblog}) {
                            $status->{content} = 'BT '. $status->{reblog}{account}{acct}. ': '. $status->{content};
                        }

                        if ($status->{account}{acct} !~ /\@/) {
                            $status->{account}{acct} = $status->{account}{acct}. '@'. (split /\@/, $self->target->{acct})[1];
                        }

                        $status->{content} =~ s/\@everyone/\@ everyone/g;

                        if ($status->{account}{url} =~ (split /\@/, $self->target->{acct})[0] and $status->{account}{url} =~ (split /\@/, $self->target->{acct})[1]) {
                            $self->cb->({
                                display_name => $status->{account}{display_name},
                                acct => $status->{account}{acct},
                                avatar_url => $self->target->{avatar_url} || $status->{account}{avatar},
                                content => $status->{content},
                                visibility => $status->{visibility},
                                media_attachments => $status->{media_attachments}
                            });
                        }
                    }
                    $self->min_id($self->statuses->[0]{id});
                }
            };
            say $@ if $@;
        }
    );

    $self->timer($t);

    return $cv;
}

1;
