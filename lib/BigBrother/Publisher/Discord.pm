package BigBrother::Publisher::Discord;
use Moo;
use Furl;
use Encode 'encode_utf8';
use File::Temp 'tempfile';
use File::Basename 'fileparse';
use HTTP::Request::Common;
use feature 'say';

has webhook_url => (is => 'ro');
has furl => (is => 'ro', default => sub {Furl->new});

# $post: Hash Reference
#   ->{display_name}
#   ->{screen_name}
#   ->{avatar_url}
#   ->{content}
#   ->{media_attachments}: Array Reference
#     ->{url}
sub publish {
    my ($self, $post) = @_;

    say encode_utf8 $post->{display_name}.' ('.$post->{screen_name}.')';
    say encode_utf8 $post->{content};

    $self->furl->post(
        $self->webhook_url,
        [],
        [
            avatar_url => encode_utf8($post->{avatar_url}),
            content => encode_utf8($post->{content}),
            username => encode_utf8($post->{display_name} . " ($post->{screen_name})")
        ]
    );

    if (@{$post->{media_attachments}}) {
        for my $media_attachment (@{$post->{media_attachments}}) {
            say $media_attachment->{url};
            my $ext = (fileparse $media_attachment->{url}, qr/\..*$/)[2];
            my $binary = $self->furl->get($media_attachment->{url});
            my ($tmpfh, $tmpfile) = tempfile(UNLINK => 1, SUFFIX => $ext);
            print $tmpfh $binary->content;
            close $tmpfh;
            $self->furl->request(POST (
                $self->webhook_url,
                'Content-Type' => 'multipart/form-data',
                'Content' => [
                    avatar_url => encode_utf8($post->{avatar_url}),
                    file => [$tmpfile],
                    username => encode_utf8($post->{display_name} . " ($post->{screen_name})")
                ]
            ));
        }
    }
}

1;
