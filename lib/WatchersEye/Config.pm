package WatchersEye::Config;
use Moo;
use utf8;
use YAML::XS 'Load';

sub load {
    my $yaml;

    open my $fh, '<', 'config/credentials.yml';
    $yaml .= do { local $/; <$fh> };
    close $fh;

    $yaml .= "\ntargets:\n";
    for my $target (glob "config/targets/*.yml") {
        open my $fh, '<', $target;
        $yaml .= do { local $/; <$fh> };
        close $fh;
    }

    $yaml .= "\npublishers:\n";
    for my $publisher (glob "config/publishers/*.yml") {
        open my $fh, '<', $publisher;
        $yaml .= do { local $/; <$fh> };
        close $fh;
    }

    Load $yaml;
}

1;
