#!/usr/bin/perl -w

use strict;
use IPC::Cmd;
use File::Temp;
use File::Compare;
use Getopt::Long;

sub print_file($) {
    (my $fn) = @_;
    open INF, "<$fn";
    while (my $line = <INF>) {
        print $line;
    }
    close INF;
}

my $verbose = 0;
die("Error in command line arguments")
    unless GetOptions("verbose=i" => \$verbose) && ! scalar(@ARGV);

# TODO let people specify these w/o modifying this script
#my @compilers = ("gcc", "gcc-4.4", "clang");
#my @opts = ("-O0", "-O1", "-O2", "-Os", "-O3");
my @compilers = ("gcc", "clang");
my @opts = ("-O0", "-Ofast");

# TODO support C++

foreach my $compiler (@compilers) {
    if (!IPC::Cmd::can_run($compiler)) {
        print "can't run '$compiler', so skipping it\n";
        next;
    }
    foreach my $opt (@opts) {
        opendir my $dh, "." or die "$0: opendir: $!";
        my @dirs = grep {-d "./$_" && ! /^\./} readdir($dh);
        foreach my $dir (@dirs) {
            my @files = glob "$dir/*.c";
            print "no files found in '$dir'\n"
                unless (scalar(@files)>0);
            my $all_expected = 1;
            foreach my $file (sort @files) {
                print "\ntesting $compiler $opt using $file\n"
                    if ($verbose > 0);
                die unless ($file =~ /(.*)\.c$/);
                my $root = $1;
                my $exe = tmpnam();
                system "$compiler -w $opt $file -o $exe";
                my $output = tmpnam();
                system "$exe > $output";
                unlink $exe;
                my @expected_outputs = glob "$root.output*";
                die "oops: no expected outputs for '$file'\n"
                    unless (scalar(@expected_outputs)>0);
                my $expected = 0;
                foreach my $fn (@expected_outputs) {
                    my $same = (0 == File::Compare::compare($output, $fn));
                    if (!$same && $verbose > 0) {
                        print "for '$fn' expected:\n";
                        print_file($fn);
                        print "but got:\n";
                        print_file($output);
                    }
                    $expected |= $same;
                }
                unlink $output;
                $all_expected &= $expected;
            }
            my $compiler_id = "$compiler $opt";
            print "$compiler_id $dir $all_expected\n";
        }
        closedir $dh;
    }
}
