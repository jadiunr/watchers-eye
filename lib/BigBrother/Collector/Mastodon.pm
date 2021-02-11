package BigBrother::Collector::Mastodon;
use Moo;
use BigBrother::Publisher::Discord;
use IO::Async::Loop;
use Net::Async::WebSocket::Client;
use JSON::XS;
use Encode 'encode_utf8';
use feature 'say';

has settings => (is => 'ro');
has target => (is => 'ro');

sub run {
    my $self = shift;
    my $ws = Net::Async::WebSocket::Client->new(
        on_text_frame => sub {
            my $frame = $_[1];
            my $decoded_frame = decode_json encode_utf8 $frame;
            my $event = $decoded_frame->{event};
            return if $event ne 'update';
            my $post = decode_json encode_utf8 $decoded_frame->{payload};
            return if $post->{visibility} ne 'private' and $self->target->{private_only};
            if ($post->{account}{acct} eq $self->target->{acct}) {
                BigBrother::Publisher::Discord->new(
                    webhook_url => $self->settings->{publishers}{webhook_url}
                )->publish($post);
            }
        },
        on_ping_frame => sub {
            my $self = shift;
            $self->send_pong_frame->get;
        }
    );

    my $loop = IO::Async::Loop->new;
    $loop->add($ws);

    $ws->connect(
        url => "wss://".
            $self->target->{domain}.
            "/api/v1/streaming?access_token=".
            $self->target->{credentials}{token}.
            "&stream=user"
    )->then(sub {
        say "Mastodon WebSocket connected.";
    })->get;

    $loop->run;
}

1;
