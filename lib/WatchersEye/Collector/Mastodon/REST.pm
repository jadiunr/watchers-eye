package WatchersEye::Collector::Mastodon::REST;
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
    my $using_token_count = grep {$self->target->{credentials}{token} eq $_->{credentials}{token}} @{$Config->{targets}};
    return $using_token_count;
});
has timer => (is => 'rw');

sub run {
    my $self = shift;
    my %furl_args;
    $furl_args{agent} = 'Mozilla/5.0 (Windows NT 10.0; rv:68.0) Gecko/20100101 Firefox/68.0 ';
    $furl_args{headers} = ['Authorization' => "Bearer ". $self->target->{credentials}{token}] unless $self->target->{no_auth};
    $furl_args{proxy} = 'http://tor:8118' if $self->target->{use_tor};
    my $furl = Furl->new(%furl_args);
    my $endpoint = sprintf "https://%s/api/v1/accounts/%s/statuses?limit=40&exclude_replies=%s&exclude_reblogs=%s",
        $self->target->{domain}, $self->target->{account_id}, $self->target->{exclude_replies} ? 'true' : 'false', $self->target->{exclude_reblogs} ? 'true' : 'false';
    $self->statuses(decode_json $furl->get($endpoint)->content);
    $self->min_id($self->statuses->[0]{id});

    say $self->target->{label}. ": Connected. interval=". $self->interval;

    my $cv = AnyEvent->condvar;
    my $t = AnyEvent->timer(
        after => 0,
        interval => $self->interval,
        cb => sub {
            $self->statuses(decode_json $furl->get($endpoint. "&min_id=". $self->min_id)->content);

            if (@{$self->statuses}) {
                for my $status (@{$self->statuses}) {
                    next if $status->{visibility} ne 'private' and $self->target->{private_only};

                    $status->{content} =~ s/<(br|br \/|\/p)>/\n/g;
                    $status->{content} =~ s/<(".*?"|'.*?'|[^'"])*?>//g;
                    $status->{content} = decode_entities($status->{content});

                    if ($status->{account}{acct} !~ /\@/) {
                        $status->{account}{acct} = $status->{account}{acct}. '@'. $self->target->{domain};
                    }

                    $self->cb->({
                        display_name => $status->{account}{display_name},
                        acct => $status->{account}{acct},
                        avatar_url => $status->{account}{avatar},
                        content => $status->{content},
                        media_attachments => $status->{media_attachments}
                    });
                }
                $self->min_id($self->statuses->[0]{id});
            }
        }
    );

    $self->timer($t);

    return $cv;
}

1;
