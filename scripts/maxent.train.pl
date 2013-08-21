#!/usr/bin/env perl

use strict;
use utf8;
use warnings;

use Treex::Tool::ML::MaxEnt::Learner;
use Getopt::Long;

use lib 'lib';
use Utils;

my $USAGE = <<"USAGE_END";
Usage: $0 [-e <value_of_epsilon>] <resulting_model>
USAGE_END

if (@ARGV < 1) {
    print STDERR $USAGE;
    exit;
}

my $epsilon = 0.1;
GetOptions("epsilon|e=f" => \$epsilon );

# create a maximum entropy learner
my $me = Treex::Tool::ML::MaxEnt::Learner->new(); 

my $i = 0;
while (my $line = <STDIN>) {

    # print progress
    $i++;
    if ($i % 10000 == 0) {
        printf STDERR "Showing the instances to maximum entropy method. Processed lines: %d\r", $i;
    }

    my ($features, $class) = Utils::parse_line($line);
    $me->see($features, $class);
}

print STDERR "Learning a maximum entropy model...\n";
my $model = $me->learn();
print STDERR "Saving the model...\n";
$model->save($ARGV[0]);
