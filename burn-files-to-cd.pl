#!/opt/local/bin/perl -w

use strict;
use Getopt::Long;

#my $CDWRITER = "IODVDServices/0";
my $CDWRITER = "IOCompactDiscServices/0";

my $artist;
my $title;
my $ntracks = 0;
my @tracknames = ();
my @tracklengths = ();
my @trackartists = ();
my @trackfiles = ();
my $multiartist = 0;
my $infofile;

GetOptions(
    "file=s" => \$infofile,
    "artist=s" => \$artist,
    "title=s" => \$title,
    );

if (defined $infofile) {
    # Read info file
    open INFO, $infofile;
    while (my $trackfile = <INFO>) {
	chomp $trackfile;
	add_track_file($trackfile);
    }
    close INFO;
} else {
    while (my $trackfile = shift @ARGV) {
	add_track_file($trackfile);
    }
}


open TOC, ">$artist-$title.toc";
print TOC <<"END_OF_HEADER";
CD_DA
CD_TEXT {
    LANGUAGE_MAP { 0 : EN }
    LANGUAGE 0 { TITLE "$title" PERFORMER "$artist" }
}
END_OF_HEADER

for (my $i = 1; $i <= $ntracks; $i++) {
    print TOC <<"END_OF_TRACK";
TRACK AUDIO
COPY
CD_TEXT {
    LANGUAGE 0 { TITLE "$tracknames[$i]" PERFORMER "$trackartists[$i]" }
}
FILE "$trackfiles[$i]" 0

END_OF_TRACK
}

close TOC;

open INFO, ">$artist-$title.info";
print INFO $artist, "\n";
print INFO $title, "\n";
for (my $i = 1; $i <= $ntracks; $i++) {
    if ($multiartist) {
	printf INFO "%d %s: %s\n", $tracklengths[$i], $trackartists[$i], $tracknames[$i];
    } else {
	printf INFO "%d %s\n", $tracklengths[$i], $tracknames[$i];
    }
}
close INFO;

my $escaped_info_file = escape_filename_for_shell("$artist-$title.info");
system("./make-labels.pl --file $escaped_info_file");

my $escaped_toc_file = escape_filename_for_shell("$artist-$title.toc");
system("cdrdao write --device $CDWRITER --driver generic-mmc-raw $escaped_toc_file");

exit 0;

sub add_track_file {
    my ($trackfile) = @_;
    next if $trackfile eq '';
    if ($trackfile =~ m/\.ogg$/) {
	add_ogg_vorbis_track($trackfile);
    }
    if ($trackfile =~ m/\.mp3$/) {
	add_mp3_track($trackfile);
    }
}

sub add_ogg_vorbis_track {
    my $filename = shift;

    my ($length, $title, $artist);
    my $escaped = escape_filename_for_shell($filename);
    open GETINFO, "ogginfo $escaped |";
    while (my $info = <GETINFO>) {
	chomp $info;
	if ($info =~ m/Playback length: (([0-9]+)m:)?([0-9.]+)s/) {
	    $length = int $3;
	    if (defined $2) {
		$length += $2 * 60;
	    }
	}
	if ($info =~ m/title=(.*)$/) {
	    $title = $1;
	}
	if ($info =~ m/artist=(.*)$/) {
	    $artist = $1;
	}
    }
    close GETINFO;

    add_track_to_list($filename, $length, $title, $artist);
}

sub add_mp3_track {
    my $filename = shift;

    my $escaped = escape_filename_for_shell($filename);
    open GETINFO, "mp3info -p '\%S\x1c\%t\x1c\%a' $escaped |";
    my $info = <GETINFO>;
    chomp $info;
    close GETINFO;

    my ($length, $title, $artist) = split(/\x1c/, $info, 3);
    add_track_to_list($filename, $length, $title, $artist);
}

sub add_track_to_list {
    my ($filename, $tracklength, $tracktitle, $trackartist) = @_;

    if (not $trackartist and $artist) {
	$trackartist = $artist;
    }
    if (not $artist and $trackartist) {
	$artist = $trackartist;
    }

    if ($artist ne $trackartist) {
	$multiartist = 1;
    }

    $ntracks++;
    $tracklengths[$ntracks] = $tracklength;
    $tracknames[$ntracks] = $tracktitle;
    $trackartists[$ntracks] = $trackartist;
    $trackfiles[$ntracks] = $filename;
}

sub escape_filename_for_shell {
    my ($filename) = @_;
    $filename =~ s/'/'\\''/g;
    return "'$filename'";
}
