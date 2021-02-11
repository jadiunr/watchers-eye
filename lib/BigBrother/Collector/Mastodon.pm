package BigBrother::Collector::Mastodon;
use Moo;
use BigBrother::Publisher::Discord;
use IO::Async::Loop;
use Net::Async::WebSocket::Client;
use JSON::XS;
use Encode 'encode_utf8';

has settings => (is => 'ro');
has target => (is => 'ro');

sub run {
    my $self = shift;
    my $ws = Net::Async::WebSocket::Client->new(
        on_text_frame => sub {
            print "hoge\n";
            my $frame = $_[1];
            my $decoded_frame = decode_json encode_utf8 $frame;
            my $event = $decoded_frame->{event};
            return if $event ne 'update';
            my $post = decode_json encode_utf8 $decoded_frame->{payload};
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
    )->then(
        print "Mastodon WebSocket connected.\n";
    )->get;

    $loop->run;
}

1;
