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
use App::Pods2Site::Pod2HTML;
use App::Pods2Site::SiteBuilder;
use App::Pods2Site::Util qw(slashify);

use Cwd;
use File::Basename;
use File::Copy;

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
	print "Prepared ", $podCopier->getCount(), " files\n" if $args->isVerboseLevel(0);

	my $incss = $args->getCSS();
	my $bncss;
	if ($incss)
	{
		my $sitedir = $args->getSiteDir();
		$bncss = basename($incss);
		my $outcss = slashify("$sitedir/$bncss");
		my $mtimeIn = (stat($incss))[9];
		my $mtimeOut = -e $outcss ? (stat($outcss))[9] : 0; 

		if ($mtimeIn > $mtimeOut)
		{
			copy($incss, $outcss) || die("Failed to copy CSS '$incss' => '$outcss': $!\n");
			print "Copied CSS\n" if $args->isVerboseLevel(0);
		}
		else
		{
			print "Skipping uptodate CSS\n" if $args->isVerboseLevel(0);
		}
	}

	print "Generating HTML from pods\n" if $args->isVerboseLevel(0);
	my $pod2html = App::Pods2Site::Pod2HTML->new($args, $podCopier, $bncss);
	print "Generated ", $pod2html->getGenerated(), " documents (", $pod2html->getUptodate(), " up to date)\n" if $args->isVerboseLevel(0);

	my $sitebuilder = App::Pods2Site::SiteBuilder->new($args, $pod2html, $bncss);
	print "Completed site in ", $args->getSiteDir(), "\n" if $args->isVerboseLevel(0);

	chdir($cwd);
	
	return 0;
}

1;
