package WatchersEye::Collector::Misskey;
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
        "/streaming?i=".
        $self->target->{credentials}{token}
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

        my $request = {
            type => 'connect',
            body => {
                channel => 'homeTimeline',
                id => 'watchers-eye'
            }
        };
        $connection->send(encode_json $request);

        $connection->on(each_message => sub {
            my ($connection, $message) = @_;
            my $body = decode_json $message->{body};
            my $status = $body->{body}{body};
            return if ($status->{visibility} ne 'followers' and $self->target->{private_only});

            my $acct = $status->{user}{username}. (defined($status->{user}{host}) ? '@'. $status->{user}{host} : '@'. (split /@/, $self->target->{acct})[1]);

            if ($acct eq $self->target->{acct}) {
                $self->cb->({
                    display_name => $status->{user}{name},
                    acct => $acct,
                    avatar_url => $self->target->{avatar_url} || $status->{user}{avatarUrl},
                    content => $status->{text},
                    media_attachments => $status->{files}
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
