package WatchersEye::Publisher;
use Moo;
use utf8;
use WatchersEye::Publisher::Discord;
use WatchersEye::Publisher::Slack;
use Furl;
use Encode 'encode_utf8';
use File::Temp 'tempfile';
use File::Basename 'fileparse';
use HTTP::Request::Common;
use feature 'say';

has publishers => (is => 'ro');
has discord => (is => 'ro', default => sub { WatchersEye::Publisher::Discord->new });
has slack => (is => 'ro', default => sub { WatchersEye::Publisher::Slack->new });

sub publish {
    my ($self, $target, $status) = @_;

    say encode_utf8($status->{display_name}.' ('.$status->{acct}.')');
    say encode_utf8 $status->{content};

    for my $publisher (@{$self->publishers}) {
        if (grep {$_ eq $target->{label}} @{$publisher->{targets}}) {
            if ($publisher->{kind} eq 'discord') {
                $self->discord->publish($publisher->{webhook_url}, $status);
            } elsif ($publisher->{kind} eq 'slack') {
                $self->slack->publish($publisher->{credentials}{token}, $publisher->{channel}, $status);
            }
        }
    }
}

1;
