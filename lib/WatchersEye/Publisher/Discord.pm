package WatchersEye::Publisher::Discord;
use Moo;
use utf8;
use Furl;
use Encode 'encode_utf8';
use File::Temp 'tempfile';
use File::Basename 'fileparse';
use HTTP::Request::Common;
use feature 'say';

has furl => (is => 'ro', default => sub {Furl->new});

# $status: Hash Reference
#   ->{display_name}
#   ->{acct}
#   ->{avatar_url}
#   ->{content}
#   ->{media_attachments}: Array Reference
#     ->{url}
sub publish {
    my ($self, $webhook_url, $status) = @_;

    for my $try (1..5) {
        my $res = $self->furl->post(
            $webhook_url,
            [],
            [
                avatar_url => encode_utf8($status->{avatar_url}),
                content => encode_utf8($status->{content}),
                username => encode_utf8($status->{display_name} . " ($status->{acct})")
            ]
        );
        if ($res->status =~ /^2/) { last; }
        else {
            say "Got Status Code $res->status from Discord";
        }
    }

    if (@{$status->{media_attachments}}) {
        for my $media_attachment (@{$status->{media_attachments}}) {
            say $media_attachment->{url};
            my $ext = (fileparse $media_attachment->{url}, qr/\..*$/)[2];
            my $binary = $self->furl->get($media_attachment->{url});
            my ($tmpfh, $tmpfile) = tempfile(UNLINK => 1, SUFFIX => $ext);
            print $tmpfh $binary->content;
            close $tmpfh;
            for my $try (1..5) {
                my $res = $self->furl->request(POST (
                    $webhook_url,
                    'Content-Type' => 'multipart/form-data',
                    'Content' => [
                        avatar_url => encode_utf8($status->{avatar_url}),
                        file => [$tmpfile],
                        username => encode_utf8($status->{display_name} . " ($status->{acct})")
                    ]
                ));
                if ($res->status == 200) { last; }
                else {
                    say "Got Status Code ". $res->status. " from Discord";
                }
            }
        }
    }
}

1;
