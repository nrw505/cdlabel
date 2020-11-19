#!/opt/local/bin/perl -w

use strict;
use CDDB;
use POSIX;
use Getopt::Long;

my $title;
my $artist;
my @tracknames = ();
my @tracklengths = ();
my $ntracks = 0;

my $cddbtitle;
my $infofile;
GetOptions(
    "cddb-title=s" => \$cddbtitle,
    "file=s" => \$infofile,
    );

if ($infofile) {
    # Read info file
    open INFO, $infofile;
    $artist = <INFO>; chomp $artist;
    $title = <INFO>; chomp $title;
    while ((my $track = <INFO>) =~ m/\S/) {
	chomp $track;
	my ($length, $name) = split (/\s+/, $track, 2);
	$ntracks++;
	$tracknames[$ntracks] = $name;
	if ($length =~ m/([0-9]*):([0-9]*)/) {
	    $length = 60 * $1 + $2;
	}
	$tracklengths[$ntracks] = $length;
    }
    close INFO;
} else {
    my $directory;
    my $device;

    # Get info from inserted disc
    open DISKTOOL, "disktool -l |";
    while (my $line = <DISKTOOL>) {
	if ($line =~ m/Disk Appeared \('(.*)',Mountpoint = '(.*)', fsType = 'cddafs', volName = '(.*)'/) {
	    $device = $1;
	    $directory = $2;
	    $title = $3;
	    last; # only find the first one
	}
    }
    close DISKTOOL;

    if (not defined $title) {
	print "Could not find audio CD\n";
	exit 1;
    }

    my $titlere = qr/$title/i;

    print "Found $title\n";
    if (defined $cddbtitle) {
	$titlere = qr/$cddbtitle/i;
    }

    opendir CDDIR, $directory;
    while (my $entry = readdir CDDIR) {
	next if $entry eq '..' or $entry eq '.';
	if ($entry =~ m/([0-9]*)\s+(.*).aiff/) {
	    $tracknames[$1] = $2;
	}
    }


    system("diskutil unmount /dev/$device");
    open DISCID, "cd-discid /dev/$device |";
    my $cddiscid = <DISCID>;
    chomp $cddiscid;
    close DISCID;
    system("diskutil mount /dev/$device");

    print "Disc ID: $cddiscid\n";
    my @cddiscid = split /\s+/,$cddiscid;
    my $discid = shift @cddiscid;
    $ntracks = shift @cddiscid;
    my $totalseconds = pop @cddiscid;
    my @trackoffsets = @cddiscid;

    # my $cddb = CDDB->new(
    # 	Host => "freedb.musicbrainz.org",
    # 	Port => 80
    # 	);

    my $cddb = CDDB->new();

    use Data::Dumper;
    my @discs = $cddb->get_discs($discid, \@trackoffsets, $totalseconds);
    my $genre = '';
    foreach my $disc (@discs) {
	print Dumper($disc);
	my ($dgenre, $did, $dtitle) = @$disc;
	if ($dtitle =~ m/$titlere/) {
	    print "CDDB match: $dgenre / $did\n";
	    $genre = $dgenre;
	    last;
	}
    }
    if (not $genre) {
	print "CDDB fail, couldn't find title of '$title'\n";
	print "Maybe try --cddb-title= ?";
	exit 1;
    }

    my $cddb_disc = $cddb->get_disc_details($genre, $discid);

    $artist = $cddb_disc->{dtitle};
    $artist =~ s/$titlere//i;
    $artist =~ s/^\W*//;
    $artist =~ s/\W*$//;
    
    for (my $i = 1; $i <= $ntracks; $i++) {
	$tracknames[$i] = $cddb_disc->{ttitles}->[$i - 1];
	$tracklengths[$i] = $cddb_disc->{seconds}->[$i - 1];
    }
    use Data::Dumper;
    print STDERR Dumper($cddb_disc);
}

print "Artist: $artist\n";
print "Title: $title\n";

my @cdlabel_tracks = ();
my $cdlabel_tracks = '';

for (my $i = 1; $i <= $ntracks; $i++) {
    my $len = $tracklengths[$i];
    printf "%3s %s [%d:%02d]\n", "$i.", $tracknames[$i], floor($len / 60), $len % 60;
    push @cdlabel_tracks, ("$i. ".$tracknames[$i]);
}
$cdlabel_tracks = join("  ", @cdlabel_tracks);

my $cdlabel_output = '';
open TMPL, "cd-template.ps";
while (my $line = <TMPL>) {
    $cdlabel_output .= $line;
}
close TMPL;

$cdlabel_output =~ s/__TITLE__/$artist - $title/;
$cdlabel_output =~ s/__TRACKS__/$cdlabel_tracks/;

my $cdfile = escape_filename_for_shell("$artist-$title-cd.pdf");
my $slipfile = escape_filename_for_shell("$artist-$title-slip.pdf");

$cdfile =~ s@/@_@g;
$slipfile =~ s@/@_@g;

print "CD: [$cdfile]\n";
print "SLIP: [$slipfile]\n";
open CDLABEL, "| gs -sDEVICE=pdfwrite -sOutputFile=$cdfile";
#open CDLABEL, ">$artist-$title-cd.ps";
print CDLABEL $cdlabel_output;
close CDLABEL;

my $slip_output = '';
open TMPL, "slip-template.ps";
while (my $line = <TMPL>) {
    $slip_output .= $line;
}
close TMPL;

$slip_output =~ s/__ARTIST__/$artist/;
$slip_output =~ s/__TITLE__/$title/;
$slip_output =~ s/__NTRACKS__/$ntracks/;

my $slip_tracks = '';
for (my $i = 1; $i <= $ntracks; $i++) {
    my $len = $tracklengths[$i];
    $slip_tracks .= sprintf("%d (%s) ([%d:%02d]) showtrack\n", $i, $tracknames[$i], floor($len / 60), $len % 60);
}
$slip_output =~ s/__TRACKS__/$slip_tracks/;

open SLIP, "| gs -sDEVICE=pdfwrite -sOutputFile=$slipfile";
print SLIP $slip_output;
close SLIP;

exit 0;

sub escape_filename_for_shell {
    my ($filename) = @_;

    $filename =~ s/'/'\\''/g;
    return "'$filename'";
}
