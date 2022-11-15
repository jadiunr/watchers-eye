package WatchersEye::Config;
use strict;
use warnings;
use utf8;
use YAML::XS 'Load';
use Exporter 'import';

my $yaml;

open my $fh, '<', 'config/credentials.yml';
$yaml .= do { local $/; <$fh> };
$yaml .= "\n";
close $fh;

$yaml .= "\ntargets:\n";
for my $target (glob "config/targets/*.yml") {
    open my $fh, '<', $target;
    $yaml .= do { local $/; <$fh> };
    $yaml .= "\n";
    close $fh;
}

$yaml .= "\npublishers:\n";
for my $publisher (glob "config/publishers/*.yml") {
    open my $fh, '<', $publisher;
    $yaml .= do { local $/; <$fh> };
    $yaml .= "\n";
    close $fh;
}

print $yaml;

our @EXPORT = qw/$Config/;
our $Config = Load $yaml;

1;
