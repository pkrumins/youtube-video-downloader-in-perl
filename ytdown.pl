#!/usr/bin/perl
#
# Follow me on twitter: @pkrumins
# Visit my website: http://www.catonmat.net
# Email me: peter@catonmat.net
#

use warnings;
use strict;
use WWW::Mechanize;
use URI::Escape;

if (@ARGV < 1) {
    die "Usage: $0 <url>"
}

my $url = shift;

# ---

my $id = get_id($url);

my $mech = new_mech({agent => 'Chrome v6.6.6'});

$mech->get($url);
unless ($mech->success) {
    die "Failed downloading $id."
}

my $page = $mech->content;
my $video_url = get_video_url($page);
my $title = sanitize_title(get_title($page));

my $filename = "$title.flv";
my $downloaded = 0;
my $download_size;
my $file_size;
my $out_file;

if (-e $filename) {
    $file_size = -s $filename;
}

print "Downloading $id: $filename\n";
$mech->get($video_url, ':content_cb' => \&progress_cb);
unless ($mech->success) {
    die "Failed downloading $filename.\n";
}
print_percent($downloaded, $download_size, "\n");
close $out_file;

if ($download_size != $downloaded) {
    die "Failed downloading $filename, partial download.\n";
}

# ---

sub progress_cb {
    my ($data, $response, $proto) = @_;
    unless (defined $download_size) {
        $download_size = $response->header('Content-Length');
        if (defined $file_size && $file_size == $download_size) {
            print "File $filename has already been downloaded.\n";
            exit;
        }
        open $out_file, '>', $filename or die "Failed opening $filename.";
    }
    syswrite $out_file, $data;
    $downloaded += length($data);
    print_percent($downloaded, $download_size, "\r");
}

sub percent {
    my ($now, $total) = @_;
    return $now/$total*100;
}

sub print_percent {
    my ($now, $total, $term) = @_;
    printf "%d/%d (%.2f%%)$term", $downloaded, $download_size, percent($downloaded, $download_size);
}

# ---

sub get_id {
    my $url = shift;

    $url =~ s|http://||;
    $url =~ s|www\.||;
    $url =~ s|youtube\.com/watch\?v=||;

    return (split '&', $url)[0];
}

sub get_video_url {
    my $page = shift;

    my $fmt_url_map = ($page =~ /fmt_url_map=(.+?)&amp;/g)[0];
    unless (length $fmt_url_map) {
        die "Failed getting fmt_url_map for $id."
    }
    $fmt_url_map = uri_unescape($fmt_url_map);
    $fmt_url_map =~ s|\\/|/|g;

    my @fmt_urls = split /,?[0-9]+\|/, $fmt_url_map;
    my $video_url = (grep { /itag=5/ } @fmt_urls)[0];

    unless (length $video_url) {
        die "Failed getting video url for $id.";
    }

    return $video_url;
}

sub get_title {
    my $page = shift;

    if ($page =~ m|<title>(.+)</title>|s) {
        my $title = $1;
        $title =~ s/\r|\n//g;
        $title =~ s/\s+/ /g;
        $title =~ s/^\s//;
        $title =~ s/\s$//;
        $title =~ s/YouTube - //;
        return $title;
    }
    else {
        die "Failed getting title for $id.";
    }
}

sub sanitize_title {
    my $title = shift;
    $title =~ s/[)(]//g;
    $title =~ s/[^[:alnum:]-]/_/g;
    $title =~ s/_-/-/g;
    $title =~ s/-_/-/g;
    $title =~ s/_+$//g;
    $title =~ s/-+$//g;
    $title =~ s/_{2,}/_/g;
    $title =~ s/-{2,}/_/g;
    return $title;
}

sub new_mech {
    my $mech = WWW::Mechanize->new;
    $mech->agent_alias('Windows IE 6');
    $mech;
}
