# Parses a commandline packaged as a list (e.g. normally just pass @ARGV)
# and processes it into real objects for later use by various functions
# in the Pods2Site universe
#
package App::Pods2Site::Args;

use strict;
use warnings;

use App::Pods2Site::Util qw(slashify isDirEmpty);

use Getopt::Long qw(GetOptionsFromArray :config require_order no_ignore_case bundling);
use File::Spec;
use File::Temp qw(tempdir);
use File::Slurp qw(write_file read_file);
use File::Path qw(make_path);
use Config qw(%Config);
use Pod::Usage;
use Pod::Find qw(pod_where);
use List::MoreUtils qw(uniq);
use Grep::Query;
use JSON;

# CTOR
#
sub new
{
	my $class = shift;
	my $version = shift;

	my $self = bless
				(
					{
						json => JSON->new()->utf8()->pretty()->canonical(),
						version => $version,
					},
					$class
				);
	$self->__parseArgv($version, @_);

	return $self;
}

sub getVersion
{
	my $self = shift;
	
	return $self->{version};
}

sub getOutDir
{
	my $self = shift;
	
	return $self->{outdir};
}

sub getBinDirs
{
	my $self = shift;
	
	return @{$self->{bindirs}};
}

sub getLibDirs
{
	my $self = shift;
	
	return @{$self->{libdirs}};
}

sub getWorkDir
{
	my $self = shift;
	
	return $self->{workdir};
}

sub includeScriptNames
{
	my $self = shift;
	
	return $self->__includeNames('script-include', @_);
}

sub getIncludeScriptNamesText
{
	my $self = shift;
	
	return $self->{'script-include-text'};
}

sub includeCoreNames
{
	my $self = shift;
	
	return $self->__includeNames('core-include', @_);
}
	
sub getIncludeCoreNamesText
{
	my $self = shift;
	
	return $self->{'core-include-text'};
}

sub includePragmaNames
{
	my $self = shift;
	
	return $self->__includeNames('pragma-include', @_);
}

sub getIncludePragmaNamesText
{
	my $self = shift;
	
	return $self->{'pragma-include-text'};
}

sub includeModuleNames
{
	my $self = shift;
	
	return $self->__includeNames('module-include', @_);
}

sub getIncludeModuleNamesText
{
	my $self = shift;
	
	return $self->{'module-include-text'};
}

sub getCSS
{
	my $self = shift;
	
	return $self->{css};
}

sub isVerboseLevel
{
	my $self = shift;
	my $level = shift;
	
	return $self->{verbose} >= $level;	
}

# PRIVATE
#

sub __includeNames
{
	my $self = shift;
	my $section = shift;
	my @names = @_;

	return
		$self->{$section}
			? $self->{$section}->qgrep(@names)
			: @names;
}

sub __parseArgv
{
	my $self = shift;
	my $version = shift;
	my @argv = @_;

	my @persistOpts =
		qw
			(
				bindir
				libdir
				script-include
				core-include
				pragma-include
				module-include
				css
			);
		
	my %rawOpts =
		(
			outdir => undef,
			v => 0,
			workdir => undef,
			quiet => 0,
		);
		
	my @specs =
		(
			'outdir=s',
			'v|verbose+',
			'workdir=s',
			'quiet',
			'bindir=s@',
			'libdir=s@',
			'script-include=s',
			'core-include=s',
			'pragma-include=s',
			'module-include=s',
			'css=s',
		);

	my $argsPodInput = pod_where( { -inc => 1 }, 'App::Pods2Site::Args');

	# for consistent error handling below, trap getopts problems
	# 
	eval
	{
		local $SIG{__WARN__} = sub { die(@_) };
		GetOptionsFromArray(\@argv, \%rawOpts, @specs)
	};
	if ($@)
	{
		pod2usage(-input => $argsPodInput, -message => "Failure parsing options:\n  $@", -exitval => 255, -verbose => 0);
	}

	die("You must provide --outdir\n") unless defined($rawOpts{outdir});
	my $outdir = slashify(File::Spec->rel2abs($rawOpts{outdir}));
	my $pfname = $self->__persistFileName();
	my $persistFile = slashify($outdir . "/$pfname"); 
	if (-e $outdir && !isDirEmpty($outdir, [$pfname]))
	{
		die("The output '$outdir' exists, but is not a directory\n") unless -d $outdir;
		die("The output '$outdir' exists, but is missing our marker file\n") unless -f $persistFile;
		print "NOTE: reusing options from '$persistFile'!\n";
		foreach my $opt (@persistOpts)
		{
			die("Some options can't be used when updating an existing -outdir '$outdir' (option '$opt' found)\n") if exists($rawOpts{$opt});
		}
		my $po = $self->__readOpts($persistFile);
		%rawOpts = ( %rawOpts, %$po );
	}
	else
	{
		if (!-d $outdir)
		{
			mkdir($outdir) || die("Failed to create -outdir '$outdir': $!\n");
		}
		my %po = map { $_ => $rawOpts{$_} } @persistOpts;
		$self->__writeOpts($persistFile, \%po);
	}
	$self->{outdir} = $outdir;
	
	my @bindirs = uniq($self->__getBinLocations($rawOpts{bindir}));
	warn("WARNING: No bin directories found\n") unless @bindirs;
	$self->{bindirs} = \@bindirs;

	my @libdirs = uniq($self->__getLibLocations($rawOpts{libdir}));
	warn("WARNING: No lib directories found\n") unless @libdirs;
	$self->{libdirs} = \@libdirs;

	my $workdir;
	if ($rawOpts{workdir})
	{
		# if user specifies a workdir this implies that it should be kept
		# just make sure there is no such directory beforehand, and create it here
		# (similar to below; tempdir() will also create one)
		#
		$workdir = slashify(File::Spec->rel2abs($rawOpts{workdir}));
		die("The workdir '$workdir' already exists\n") if -e $workdir;
		make_path($workdir) or die("Failed to create workdir '$workdir': $!\n");
	}
	else
	{
		# create a temp dir; use automatic cleanup
		#
		$workdir = slashify(tempdir("pods2site-XXXX", TMPDIR => 1, CLEANUP => 1));
	}
	$self->{workdir} = $workdir;

	# create the user include filter for pruning the list of script names later
	#
	eval
	{
		my $inc = $rawOpts{'script-include'};
		$self->{'script-include'} =
			defined($inc)
				? Grep::Query->new($inc)
				: undef;
		$self->{'script-include-text'} = $inc;
	};
	if ($@)
	{
		pod2usage(-message => "Failure creating script-include filter:\n  $@", -exitval => 255, -verbose => 0);
	}

	# create the user include filter for pruning the list of core names later
	#
	eval
	{
		my $inc = $rawOpts{'core-include'};
		$self->{'core-include'} =
			defined($inc)
				? Grep::Query->new($inc)
				: undef;
		$self->{'core-include-text'} = $inc;
	};
	if ($@)
	{
		pod2usage(-message => "Failure creating core-include filter:\n  $@", -exitval => 255, -verbose => 0);
	}

	# create the user include filter for pruning the list of pragma names later
	#
	eval
	{
		my $inc = $rawOpts{'pragma-include'};
		$self->{'pragma-include'} =
			defined($inc)
				? Grep::Query->new($inc)
				: undef;
		$self->{'pragma-include-text'} = $inc;
	};
	if ($@)
	{
		pod2usage(-message => "Failure creating pragma-include filter:\n  $@", -exitval => 255, -verbose => 0);
	}

	# create the user include filter for pruning the list of module names later
	#
	eval
	{
		my $inc = $rawOpts{'module-include'};
		$self->{'module-include'} =
			defined($inc)
				? Grep::Query->new($inc)
				: undef;
		$self->{'module-include-text'} = $inc;
	};
	if ($@)
	{
		pod2usage(-message => "Failure creating module-include filter:\n  $@", -exitval => 255, -verbose => 0);
	}
	
	my $css = slashify(File::Spec->rel2abs($rawOpts{css})) if $rawOpts{css};
	if ($css)
	{
		die("No such file: -css '$css'\n") unless -f $css;
		$self->{css} = $css
	}
		
	$self->{verbose} = $rawOpts{quiet} ? -1 : $rawOpts{v};
}

sub __getBinLocations
{
	my $self = shift;
	my $argLocs = shift;
	
	my @locs;
	if (defined($argLocs))
	{
		foreach my $loc (@$argLocs)
		{
			if (defined($loc) && length($loc) > 0)
			{
				if ($loc eq ':std')
				{
					push(@locs, $self->__getDefaultBinLocations());
				}
				elsif ($loc eq ':none')
				{
					# do nothing
				}
				else
				{
					push(@locs, $loc) if -d $loc;
				}
			}
		}
	}
	else
	{
		@locs = $self->__getDefaultBinLocations();
	}
	
	$_ = slashify(File::Spec->rel2abs($_)) foreach (@locs);
	
	return @locs;
}

sub __getLibLocations
{
	my $self = shift;
	my $argLocs = shift;
	
	my @locs;
	if (defined($argLocs))
	{
		foreach my $loc (@$argLocs)
		{
			if (defined($loc) && length($loc) > 0)
			{
				if ($loc eq ':std')
				{
					push(@locs, $self->__getDefaultLibLocations());
				}
				elsif ($loc eq ':inc')
				{
					push(@locs, @INC);
				}
				elsif ($loc eq ':none')
				{
					# do nothing
				}
				else
				{
					push(@locs, $loc) if -d $loc;
				}
			}
		}
	}
	else
	{
		@locs = $self->__getDefaultLibLocations();
	}
	
	$_ = slashify(File::Spec->rel2abs($_)) foreach (@locs);

	return @locs;
}

sub __getDefaultBinLocations
{
	my $self = shift;

	return $self->__getConfigLocations
		(
			qw
				(
					installsitebin
					installsitescript
					installvendorbin
					installvendorscript
					installbin
					installscript
				)
		);
}

sub __getDefaultLibLocations
{
	my $self = shift;
	
	return $self->__getConfigLocations
		(
			qw
				(
					installsitearch
					installsiteslib
					installvendorarch
					installvendorlib
					installarchlib
					installprivlib
				)
		);
}

sub __getConfigLocations
{
	my $self = shift;
	my @cfgnames = @_;

	my @locs;
	foreach my $loc (@cfgnames)
	{
		my $cfgloc = $Config{$loc};
		if (	defined($cfgloc)
			&&	length($cfgloc) > 0
			&& -d $cfgloc)
		{
			push(@locs, $cfgloc);
		}
	}	
	
	return @locs;
}

sub __persistFileName
{
	return '.pods2site-opts';
}

sub __writeOpts
{
	my $self = shift;
	my $file = shift;
	my $opts = shift;
	
	write_file($file, $self->{json}->encode($opts)) || die("Failed to write '$file': $!\n");
}

sub __readOpts
{
	my $self = shift;
	my $file = shift;
	
	my $txt = read_file($file) || die("Failed to read '$file': $!\n");
	
	return $self->{json}->decode($txt);
}

1;
