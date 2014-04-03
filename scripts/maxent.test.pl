#!/usr/bin/env perl

use strict;
use utf8;
use warnings;

use Treex::Tool::ML::MaxEnt::Model;
use Treex::Tool::ML::TabSpace::Util;

my $USAGE = <<"USAGE_END";
Usage: $0 <max_ent_model>
USAGE_END

if (@ARGV < 1) {
    print STDERR $USAGE;
    exit;
}

my $model = Treex::Tool::ML::MaxEnt::Model->new();
$model->load($ARGV[0]);

my $i = 0;
while (my $line = <STDIN>) {
    
    # print progress
    $i++;
    if ($i % 10000 == 0) {
        printf STDERR "Resolving the data using maximum entropy model. Processed lines: %d\r", $i;
    }

    my ($features, $class) = Treex::Tool::ML::TabSpace::Util::parse_line($line);
    my $pred_class = $model->predict($features);

    print "$class\t$pred_class\n";
}
