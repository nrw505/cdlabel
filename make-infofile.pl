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
my $skip_cddb = 0;
my $infofile;
GetOptions(
    "cddb-title=s" => \$cddbtitle,
    "skip-cddb" => \$skip_cddb,
    );

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
	$ntracks++
    }
}

if (!$skip_cddb) {
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


print "$artist\n";
print "$title\n";
for (my $i = 0; $i < $ntracks; $i++) {
    if (exists $tracklengths[$i]) {
	my $len = $tracklengths[$i];
	print sprintf("%d:%02d ", floor($len / 60), $len % 60);
    }
    print $tracknames[$i];
    print "\n";
}

