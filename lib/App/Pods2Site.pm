package App::Pods2Site;

use 5.010;

use strict;
use warnings;

our $VERSION = '0.001';
my $version = $VERSION;
$VERSION = eval $VERSION;

use App::Pods2Site::Args;
use App::Pods2Site::PodFinder;
use App::Pods2Site::PodCopier;
use App::Pods2Site::Writer;
use App::Pods2Site::Util qw(slashify);

use Cwd;

# main entry point
#
sub main
{
	my $args = App::Pods2Site::Args->new(@_);

	my $cwd = slashify(getcwd());
	
	my $workdir = $args->getWorkDir();
	chdir($workdir) || die("Failed to chdir to '$workdir': $!\n");
	
	if ($args->isVerboseLevel(0))
	{
		print "Scanning for pods in:\n";
		print "  $_\n" foreach ($args->getBinDirs(), $args->getLibDirs());
	}
	
	my $podFinder = App::Pods2Site::PodFinder->new($args);
	print "Found ", $podFinder->getCount(), " pods\n" if $args->isVerboseLevel(0);

	print "Preparing pod work tree\n" if $args->isVerboseLevel(0);
	my $podCopier = App::Pods2Site::PodCopier->new($args, $podFinder);

die;
	print "Updating site in ", $args->getOutDir(), "\n" if $args->isVerboseLevel(0);
	my $writer = App::Pods2Site::Writer->new($args, $podFinder);
	print "Updated ", $writer->getWritten(), " html files\n" if $args->isVerboseLevel(0);

	chdir($cwd);
	
	return 0;
}

1;
