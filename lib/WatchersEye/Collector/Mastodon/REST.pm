package WatchersEye::Collector::Mastodon::REST;
use Moo;
use utf8;
use AnyEvent;
use JSON::XS;
use Furl;
use Encode 'encode_utf8';
use HTML::Entities 'decode_entities';
use feature 'say';

has target => (is => 'ro');
has cb => (is => 'ro');
has statuses => (is => 'rw');
has min_id => (is => 'rw');

sub run {
    my $self = shift;
    my %furl_args;
    $furl_args{headers} = ['Authorization' => "Bearer ". $self->target->{credentials}{token}] unless $self->target->{no_auth};
    $furl_args{proxy} = 'http://tor:8118' if $self->target->{use_tor};
    my $furl = Furl->new(%furl_args);
    my $endpoint = "https://". $self->target->{domain}. "/api/v1/accounts/". $self->target->{account_id}. "/statuses?limit=40&exclude_replies=false";
    $self->statuses(decode_json $furl->get($endpoint)->content);
    $self->min_id($self->statuses->[0]{id});

    my $cv = AnyEvent->condvar;
    our $t; $t = AnyEvent->timer(
        after => 0,
        interval => 60,
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

    return $cv;
}

1;
