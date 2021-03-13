package BigBrother::Collector::Misskey;
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
        "/streaming?i=".
        $self->target->{credentials}{token}
    )->cb(sub {
        my $connection = eval{ shift->recv };
        die $@ if $@;

        $self->connection($connection);

        my $request = {
            type => 'connect',
            body => {
                channel => 'homeTimeline',
                id => 'big-brother'
            }
        };
        $connection->send(encode_json $request);

        $connection->on(each_message => sub {
            my ($connection, $message) = @_;
            my $body = decode_json $message->{body};
            my $status = $body->{body}{body};
            return if $status->{visibility} ne 'followers' and $self->target->{private_only};

            if ((split /@/, $status->{user}{username})[0] eq $self->target->{screen_name}) {
                $self->cb->({
                    display_name => $status->{user}{name},
                    screen_name => $status->{user}{username},
                    avatar_url => $status->{user}{avatarUrl},
                    content => $status->{text},
                    media_attachments => $status->{files}
                });
            }
        });

        $connection->on(finish => sub {
            $self->connection->close;
            $self->run;
        });
    });

    return $cv;
}

1;
