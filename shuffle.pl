#!/usr/bin/env perl -w

use strict;
use warnings qw(all);
use 5.12.0;
use utf8;
use File::Slurp;

my ($timetable_filename, $spots_filename, $team_template_filename, $spot_template_filename) = @ARGV;
die "Usage: $0 timetable-filename spots-filename team-template-filename spot-template-filename\n"
    unless $spot_template_filename;

my ($head, @rows) = map { chomp; $_ } read_file($timetable_filename);
my $team_template = read_file($team_template_filename, {binmode => ':utf8'});
my $spot_template = read_file($spot_template_filename, {binmode => ':utf8'});
my @spots_list = read_file($spots_filename, {binmode => ':utf8'});

my ($alkaa, $loppuu, @slots) = split(/\t+/, $head);

my @slot_spots = map { s/\d//; $_ } @slots;

print "@slot_spots\n";

my %team_at_spot = ();
my %team_at_time = ();
my %spot_at_time = ();

my %spot_titles = map { /^(\w)/ => $_ } @spots_list;

sub add_time ($$) {
    my ($time, $add_minutes) = @_;
    my ($hour, $minutes) = split /:/, $time;
    $minutes += $add_minutes;
    return sprintf("%02d:%02d", $hour + int($minutes / 60), $minutes % 60);
}

for my $row (@rows) {
    my ($start, $end, @teams) = split(/\t+/, $row);

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
            push @{$spot_at_time{$spot}{$time} ||= []}, $team;
            $time = add_time($time, 12); # for combined spots, split time to complete both
        }
    }
}

sub fill_template ($$);

sub fill_template ($$) {
    my ($template, $data) = @_;

    if ($template =~ /^(.*?)\s*<loop (\w+)>(.*?)\s*<\/loop \2>(.*)$/s) {
        my ($before, $loop_name, $loop_template, $after) = ($1, $2, $3, $4);
        my @looped = map { fill_template($loop_template, $_) } @{$data->{$loop_name}};
        $template = join '',
            fill_template($before, $data),
            @looped,
            fill_template($after, $data);
    } else {
        $template =~ s/{(\w+)}/$data->{$1} || "$1?"/eg;
    }

    return $template
}

sub write_file_from_template ($$$) {
    my ($filename, $template, $data) = @_;
    open my $fh, ">", "$filename";
    binmode($fh, ':utf8');
    print $fh fill_template($template, $data);
    close $fh;
}

for my $team (sort keys %team_at_time) {
    my $times = $team_at_time{$team};
    my $type = $team < 20 ? 'Sudenpentu' : 'Seikkailija';

    write_file_from_template(
        "$type-$team.html",
        $team_template,
        {
            ikaryhma => $type,
            nro => $team,
            lajit => [
                map {{
                    aika => $_,
                    laji => $spot_titles{$times->{$_}},
                }} sort keys %$times
            ],
        }
    );
}

for my $spot (sort keys %spot_at_time) {
    my $times = $spot_at_time{$spot};
    my $slot_count = grep(/^$spot/, @slot_spots);

    write_file_from_template(
        "rasti-$spot.html",
        $spot_template,
        {
            rasti => $spot,
            nimi => $spot_titles{$spot},
            joukkueet => [
                map {{
                    joukkue => "Joukkue $_"
                }} ($slot_count > 2 ? (1, 2) : ())
            ],
            slotit => [
                map {{
                    slot => ($_ % 2)
                        ? "Sudenpennut"
                        : "Seikkailijat"
                }} (1 .. $slot_count)
            ],
            ajat => [
                map {{
                    aika => $_,
                    vartiot => [
                        map {{
                            vartio => "vartio $_"
                        }} @{$times->{$_}}
                    ]
                }} sort keys %$times
            ]
        }
    );
}
