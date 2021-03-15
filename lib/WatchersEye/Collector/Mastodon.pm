package WatchersEye::Collector::Mastodon;
use Moo;
use utf8;
use AnyEvent::WebSocket::Client;
use JSON::XS;
use Encode 'encode_utf8';
use feature 'say';
use HTML::Entities 'decode_entities';

has target => (is => 'ro');
has cb => (is => 'ro');
has connection => (is => 'rw');

sub run {
    my $self = shift;
    my $cv = AnyEvent->condvar;
    my $ws = AnyEvent::WebSocket::Client->new;

    $ws->connect(
        "wss://".
        $self->target->{domain}.
        "/api/v1/streaming?access_token=".
        $self->target->{credentials}{token}.
        "&stream=user"
    )->cb(sub {
        my $connection = eval{ shift->recv };
        die $@ if $@;

        $self->connection($connection);

        $connection->on(each_message => sub {
            my ($connection, $message) = @_;
            my $body = decode_json $message->{body};
            return if $body->{event} ne 'update';
            my $status = decode_json(encode_utf8 $body->{payload});
            return if $status->{visibility} ne 'private' and $self->target->{private_only};

            $status->{content} =~ s/<(br|br \/|\/p)>/\n/g;
            $status->{content} =~ s/<(".*?"|'.*?'|[^'"])*?>//g;
            $status->{content} = decode_entities($status->{content});

            if ($status->{account}{acct} !~ /\@/) {
                $status->{account}{acct} = $status->{account}{acct}. '@'. (split /@/, $self->target->{acct})[1];
            }

            if ($status->{account}{acct} eq $self->target->{acct}) {
                $self->cb->({
                    display_name => $status->{account}{display_name},
                    acct => $status->{account}{acct},
                    avatar_url => $status->{account}{avatar},
                    content => $status->{content},
                    media_attachments => $status->{media_attachments}
                });
            }
        });

        $connection->on(parse_error => sub {
            my ($connection, $message) = @_;
            say $message;
        });

        $connection->on(finish => sub {
            my $connection = shift;
            say $connection->close_error;
            $self->connection->close;
            $self->run;
        });
    });

    return $cv;
}

1;
