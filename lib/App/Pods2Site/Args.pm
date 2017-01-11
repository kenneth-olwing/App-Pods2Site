# Parses a commandline packaged as a list (e.g. normally just pass @ARGV)
# and processes it into real objects for later use by various functions
# in the Pods2Site universe
#
package App::Pods2Site::Args;

use strict;
use warnings;

use App::Pods2Site::Util qw(slashify readData writeData);

use Getopt::Long qw(GetOptionsFromArray :config require_order no_ignore_case bundling);
use File::Spec;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Config qw(%Config);
use Pod::Usage;
use Pod::Find qw(pod_where);
use List::MoreUtils qw(uniq);
use Grep::Query;

# CTOR
#
sub new
{
	my $class = shift;

	my $self = bless( {}, $class);
	$self->__parseArgv(@_);

	return $self;
}

sub getSiteDir
{
	my $self = shift;
	
	return $self->{sitedir};
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

sub getFilter
{
	my $self = shift;
	my $section = shift;
	
	return $self->{"${section}filter"};
}
#sub includeScriptNames
#{
#	my $self = shift;
#	
#	return $self->__includeNames('script-include', @_);
#}
#
#sub getIncludeScriptNamesText
#{
#	my $self = shift;
#	
#	return $self->{'script-include-text'};
#}
#
#sub includeCoreNames
#{
#	my $self = shift;
#	
#	return $self->__includeNames('core-include', @_);
#}
#	
#sub getIncludeCoreNamesText
#{
#	my $self = shift;
#	
#	return $self->{'core-include-text'};
#}
#
#sub includePragmaNames
#{
#	my $self = shift;
#	
#	return $self->__includeNames('pragma-include', @_);
#}
#
#sub getIncludePragmaNamesText
#{
#	my $self = shift;
#	
#	return $self->{'pragma-include-text'};
#}
#
#sub includeModuleNames
#{
#	my $self = shift;
#	
#	return $self->__includeNames('module-include', @_);
#}
#
#sub getIncludeModuleNamesText
#{
#	my $self = shift;
#	
#	return $self->{'module-include-text'};
#}

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

#sub __includeNames
#{
#	my $self = shift;
#	my $section = shift;
#	my @names = @_;
#
#	return
#		$self->{$section}
#			? $self->{$section}->qgrep(@names)
#			: @names;
#}

sub __parseArgv
{
	my $self = shift;
	my @argv = @_;

	# these options are persisted to the site
	# and can't be used when updating
	#	
	my @stickyOpts =
		qw
			(
				bindirectory
				libdirectory
				script-include
				core-include
				pragma-include
				module-include
				css
			);
		
	my %rawOpts =
		(
			usage => 0,
			help => 0,
			manual => 0,
			v => 0,
			workdirectory => undef,
			quiet => 0,
		);
		
	my @specs =
		(
			'usage|?',
			'help',
			'manual',
			'version',
			'v|verbose+',
			'workdirectory=s',
			'quiet',
			'bindirectory=s@',
			'libdirectory=s@',
			'script-include=s',
			'core-include=s',
			'pragma-include=s',
			'module-include=s',
			'css=s',
		);

	my $argsPodInput = pod_where( { -inc => 1 }, 'App::Pods2Site::Args');
	my $manualPodInput = pod_where( { -inc => 1 }, 'App::TestOnTap');

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

	# if any of the doc switches made, display the pod
	#
	pod2usage(-input => $manualPodInput, -exitval => 0, -verbose => 2, -noperldoc => 1) if $rawOpts{manual};
	pod2usage(-input => $argsPodInput, -exitval => 0, -verbose => 2, -noperldoc => 1) if $rawOpts{help};
	pod2usage(-input => $argsPodInput, -exitval => 0, -verbose => 0) if $rawOpts{usage};
	pod2usage(-message => "$0 version $App::Pods2Site::VERSION", -exitval => 0, -verbose => 99, -sections => '_') if $rawOpts{version};

	# manage the sitedir
	#
	my $sitedir = $argv[0];
	die("You must provide a sitedir\n") unless $sitedir;
	$sitedir = slashify(File::Spec->rel2abs($sitedir));
	if (-e $sitedir)
	{
		# if the sitedir exists as a dir, our sticky opts better be found in it
		# otherwise it's not a sitedir
		#
		die("The output '$sitedir' exists, but is not a directory\n") unless -d $sitedir;
		my $savedOpts = readData($sitedir, 'opts');
		die("The sitedir '$sitedir' exists, but is missing our marker file\n") unless $savedOpts;

		# clean up any sticky opts given by the user
		#
		print "NOTE: reusing options used when creating '$sitedir'!\n";
		foreach my $opt (@stickyOpts)
		{
			warn("WARNING: The option '$opt' can't be used when updating the existing site '$sitedir' - ignoring\n") if exists($rawOpts{$opt});
			delete($rawOpts{$opt});
		}
		%rawOpts = ( %rawOpts, %$savedOpts );
	}
	else
	{
		# create the sitedir and persist our sticky options
		#
		make_path($sitedir) || die("Failed to create sitedir '$sitedir': $!\n");
		my %opts2save = map { $_ => $rawOpts{$_} } @stickyOpts;
		writeData($sitedir, 'opts', \%opts2save);
	}
	$self->{sitedir} = $sitedir;
	
	# fix up any user given bindir locations or get us the standard ones
	#
	my @bindirs = uniq($self->__getBinLocations($rawOpts{bindir}));
	warn("WARNING: No bin directories found\n") unless @bindirs;
	$self->{bindirs} = \@bindirs;

	# fix up any user given libdir locations or get us the standard ones
	#
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
		$self->{scriptfilter} =
			defined($inc)
				? Grep::Query->new($inc)
				: undef;
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
		$self->{'corefilter'} =
			defined($inc)
				? Grep::Query->new($inc)
				: undef;
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
		$self->{pragmafilter} =
			defined($inc)
				? Grep::Query->new($inc)
				: undef;
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
		$self->{modulefilter} =
			defined($inc)
				? Grep::Query->new($inc)
				: undef;
	};
	if ($@)
	{
		pod2usage(-message => "Failure creating module-include filter:\n  $@", -exitval => 255, -verbose => 0);
	}

	# fix up any css path given by user
	#	
	my $css = slashify(File::Spec->rel2abs($rawOpts{css})) if $rawOpts{css};
	if ($css)
	{
		die("No such file: -css '$css'\n") unless -f $css;
		$self->{css} = $css
	}
	
	# if -quiet has been given, it trumps any verbosity
	#	
	$self->{verbose} = $rawOpts{quiet} ? -1 : $rawOpts{v};
}

sub __getBinLocations
{
	my $self = shift;
	my $argLocs = shift;
	
	# if the user provided any bin locations, interpret them
	# otherwise return the default places
	#
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

	# ensure all paths are absolute and clean
	#	
	$_ = slashify(File::Spec->rel2abs($_)) foreach (@locs);
	
	return @locs;
}

sub __getLibLocations
{
	my $self = shift;
	my $argLocs = shift;
	
	# if the user provided any lib locations, interpret them
	# otherwise return the default places
	#
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
	
	# ensure all paths are absolute and clean
	#	
	$_ = slashify(File::Spec->rel2abs($_)) foreach (@locs);

	return @locs;
}

sub __getDefaultBinLocations
{
	my $self = shift;

	# a somewhat guessed list for Config keys for scripts...
	# note: order is important
	#
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
	
	# a somewhat guessed list for Config keys for lib locations...
	# note: order is important
	#
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

	# the keys don't always contain anything useful
	#
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

1;
