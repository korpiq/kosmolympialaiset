#!/usr/bin/env perl -w

use strict;
use warnings qw(all);
use 5.12.0;
use utf8;
use File::Slurp;

my ($timetable_filename, $team_template_filename) = @ARGV;
die "Usage: $0 timetable-filename team-template-filename\n" unless $team_template_filename;

my $team_template = read_file($team_template_filename, {binmode => ':utf8'});
my ($head, @rows) = map { chomp; $_ } read_file($timetable_filename);

my ($alkaa, $loppuu, @slots) = split(/\t+/, $head);

my @slot_spots = map { s/\d//; $_ } @slots;

print "@slot_spots\n";

my %team_at_spot = ();
my %team_at_time = ();

my %spot_titles = (
    'A' => 'A) Asteroidien veden ryöstö',
    'B' => 'B) Lämpökilpilentopallo',
    'C' => 'C) UFO-potkupallo',
    'D' => 'D) Satelliittipolttopallo',
    'E' => 'E) Avaruuskävelyrata',
    'F' => 'F) Laskeutumisalusta',
);

sub add_time ($$) {
    my ($time, $add_minutes) = @_;
    my ($hour, $minutes) = split /:/, $time;
    $minutes += $add_minutes;
    return sprintf("%02d:%02d", $hour + int($minutes / 60), $minutes % 60);
}

for my $row (@rows) {
    my ($start, $end, @teams) = split(/\t+/, $row);
    print "@teams\n";

    for (my $i=0; $i < @teams; ++$i) {
        my $team = $teams[$i];
        my $time = $start;
        my @spots = split '', $slot_spots[$i];
        for my $spot (@spots) {
            if ($team_at_spot{$team}{$spot}) {
                die "$team at $spot already at $team_at_spot{$team}{$spot} setting $time!\n";
            }
            if ($team_at_time{$team}{$time}) {
                die "$team at $time already at $team_at_time{$team}{$time} setting $spot!\n";
            }
            $team_at_spot{$team}{$spot} = $time;
            $team_at_time{$team}{$time} = $spot;
            $time = add_time($time, 10); # for combined spots, give 10 minutes to complete first
        }
    }
}

sub fill_template ($$) {
    my ($template, $data) = @_;
    while ($template =~ /(.*)\s*<loop (\w+)>(.*?)\s*<\/loop \2>(.*)/s) {
        my ($before, $loop_name, $loop_template, $after) = ($1, $2, $3, $4);
        my @looped = map { fill_template($loop_template, $_) } @{$data->{$loop_name}};
        $template = join '', $before, @looped, $after;
    }
    $template =~ s/{(\w+)}/$data->{$1} || "$1?"/eg;
    return $template
}

for my $team (sort keys %team_at_time) {
    my $times = $team_at_time{$team};
    print "$team\n";
    my @loopdata = ();
    for my $time (sort keys %$times) {
        print "- $time: $times->{$time}\n";
        push @loopdata, {
            aika => $time,
            laji => $spot_titles{$times->{$time}},
        };
    }
    my $type = $team < 20 ? 'Sudenpentu' : 'Seikkailija';
    my %data = (
        'ikaryhma' => $type,
        nro => $team,
        lajit => \@loopdata,
    );

    open my $fh, ">", "$type-$team.html";
    binmode($fh, ':utf8');
    print $fh fill_template($team_template, \%data);
    close $fh;
}
