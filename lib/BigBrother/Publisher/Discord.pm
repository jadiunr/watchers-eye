package BigBrother::Publisher::Discord;
use Moo;
use Furl;
use Encode 'encode_utf8';
use File::Temp 'tempfile';
use File::Basename 'fileparse';
use HTTP::Request::Common;

has webhook_url => (is => 'ro');
has furl => (is => 'ro', default => sub {Furl->new});

sub publish {
    my ($self, $post) = @_;

    print encode_utf8 $post->{account}{display_name}.' ('.$post->{account}{acct}.')';
    print encode_utf8 $post->{content};
    print encode_utf8 $post->{created_at};

    $self->furl->post(
        $self->webhook_url,
        [],
        [
            avatar_url => encode_utf8($post->{account}{avatar}),
            content => encode_utf8($post->{content}),
            username => encode_utf8($post->{account}{display_name} . " ($post->{account}{acct})")
        ]
    );

    if (@{$post->{media_attachments}}) {
        for my $media_attachment (@{$post->{media_attachments}}) {
            print $media_attachment->{url}."\n";
            my $ext = (fileparse $media_attachment->{url}, qr/\..*$/)[2];
            my $binary = $self->furl->get($media_attachment->{url});
            my ($tmpfh, $tmpfile) = tempfile(UNLINK => 1, SUFFIX => $ext);
            print $tmpfh $binary->content;
            close $tmpfh;
            $self->furl->request(POST (
                $self->webhook_url,
                'Content-Type' => 'multipart/form-data',
                'Content' => [
                    avatar_url => encode_utf8($post->{account}{avatar}),
                    file => [$tmpfile],
                    username => encode_utf8($post->{account}{display_name} . " ($post->{account}{acct})")
                ]
            ));
        }
    }
}

1;
