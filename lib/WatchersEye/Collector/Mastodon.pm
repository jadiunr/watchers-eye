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
has heartbeat_timer => (is => 'rw');

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
        if ($@) {
            warn $self->target->{label}. ": Cannot connected! reason: $@";
            sleep 5;
            $self->run;
            return;
        }

        say $self->target->{label}. ": Connected.";

        $self->connection($connection);

        $connection->on(each_message => sub {
            my ($connection, $message) = @_;
            my $body = decode_json $message->{body};
            return if $body->{event} ne 'update';
            my $status = decode_json(encode_utf8 $body->{payload});

            return if ($status->{visibility} ne 'private' and $self->target->{private_only});
            return if ($status->{reblog} and $self->target->{exclude_bts});

            if ($status->{spoiler_text}) {
                $status->{content} = 'CW: '. $status->{spoiler_text}. "\n\n". $status->{content};
            }

            if ($status->{reblog}) {
                $status->{content} = 'BT '. $status->{reblog}{account}{acct}. ': '. $status->{reblog}{content};
                $status->{media_attachments} = $status->{reblog}{media_attachments};
                $status->{url} = $status->{reblog}{url};
            }

            if ($status->{account}{acct} !~ /\@/) {
                $status->{account}{acct} = $status->{account}{acct}. '@'. (split /\@/, $self->target->{acct})[1];
            }

            $status->{content} =~ s/<(br|br \/|\/p)>/\n/g;
            $status->{content} =~ s/<(".*?"|'.*?'|[^'"])*?>//g;
            $status->{content} = decode_entities($status->{content});
            $status->{content} .= "\nOrig URL: ". substr($status->{url}, 1);
            # Discord 側でエスケープできなくてうっさいので苦肉の策として
            $status->{content} =~ s/\@everyone/\@ everyone/g;
            $status->{content} =~ s/\@here/\@ here/g;

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
        });

        $connection->on(parse_error => sub {
            my ($connection, $message) = @_;
            warn $message;
            $self->connection->close;
            $self->run;
        });

        $connection->on(finish => sub {
            my $connection = shift;
            warn $connection->close_error;
            $self->connection->close;
            $self->run;
        });

        my $t = AnyEvent->timer(
            after => 30,
            interval => 30,
            cb => sub {
                $self->connection->send(AnyEvent::WebSocket::Message->new(opcode => 9, body => ''));
            },
        );

        $self->heartbeat_timer($t);
    });

    return $cv;
}

1;
