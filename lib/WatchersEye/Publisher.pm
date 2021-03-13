package WatchersEye::Publisher;
use Moo;
use utf8;
use WatchersEye::Publisher::Discord;
use Furl;
use Encode 'encode_utf8';
use File::Temp 'tempfile';
use File::Basename 'fileparse';
use HTTP::Request::Common;
use feature 'say';

has publishers => (is => 'ro');
has discord => (is => 'ro', default => sub { WatchersEye::Publisher::Discord->new });

sub publish {
    my ($self, $target, $status) = @_;

    say encode_utf8($status->{display_name}.' ('.$status->{screen_name}.')');
    say encode_utf8 $status->{content};

    for my $publisher (@{$self->publishers}) {
        if (grep {$_ eq $target->{label}} @{$publisher->{targets}}) {
            my $kind = $publisher->{kind};
            $self->$kind->publish($publisher->{webhook_url}, $status);
        }
    }
}

1;
