package BigBrother::Collector::Misskey;
use Moo;
use BigBrother::Publisher::Discord;
use IO::Async::Loop;
use Net::Async::WebSocket::Client;
use JSON::XS;
use Encode 'encode_utf8';
use feature 'say';
use HTML::Entities 'decode_entities';

has settings => (is => 'ro');
has target => (is => 'ro');
has publisher => (is => 'ro', lazy => 1, default => sub {
    my $self = shift;
    BigBrother::Publisher::Discord->new(
        webhook_url => $self->settings->{publishers}{webhook_url}
    );
});

sub run {
    my $self = shift;
    my $ws = Net::Async::WebSocket::Client->new(
        on_text_frame => sub {
            my $frame = $_[1];
            my $decoded_frame = decode_json encode_utf8 $frame;
            my $note = $decoded_frame->{body}{body};
            return if $note->{visibility} ne 'followers' and $self->target->{private_only};
            if ($note->{user}{username} eq $self->target->{acct}) {
                $self->publisher->publish({
                    display_name => $note->{user}{name},
                    screen_name => $note->{user}{username},
                    avatar_url => $note->{user}{avatarUrl},
                    content => $note->{text},
                    media_attachments => $note->{files}
                });
            }
        },
        on_ping_frame => sub {
            my ($self, $bytes) = @_;
            $self->send_pong_frame($bytes)->get;
        }
    );

    my $loop = IO::Async::Loop->new;
    $loop->add($ws);

    $ws->connect(
        url => "wss://".
            $self->target->{domain}.
            "/streaming?i=".
            $self->target->{credentials}{token}
    )->then(sub {
        say 'Misskey WebSocket connected.';
        my $self = shift;
        my $request = {
            type => 'connect',
            body => {
                channel => 'homeTimeline',
                id => 'big-brother'
            }
        };
        $self->send_text_frame(encode_json $request);
    })->get;

    $loop->run;
}

1;
