package BigBrother::Collector::Mastodon;
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
            my $event = $decoded_frame->{event};
            return if $event ne 'update';
            my $post = decode_json encode_utf8 $decoded_frame->{payload};
            return if $post->{visibility} ne 'private' and $self->target->{private_only};

            $post->{content} =~ s/<(br|br \/|\/p)>/\n/g;
            $post->{content} =~ s/<(".*?"|'.*?'|[^'"])*?>//g;
            $post->{content} = decode_entities($post->{content});

            if ($post->{account}{acct} eq $self->target->{acct}) {
                $self->publisher->publish({
                    display_name => $post->{account}{display_name},
                    screen_name => $post->{account}{acct},
                    avatar_url => $post->{account}{avatar},
                    content => $post->{content},
                    media_attachments => $post->{media_attachments}
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
            "/api/v1/streaming?access_token=".
            $self->target->{credentials}{token}.
            "&stream=user"
    )->then(sub {
        say "Mastodon WebSocket connected.";
    })->get;

    $loop->run;
}

1;
