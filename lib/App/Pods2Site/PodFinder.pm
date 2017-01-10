package App::Pods2Site::PodFinder;

use strict;
use warnings;

use App::Pods2Site::Util qw(slashify);

use Pod::Simple::Search;
use Cwd;
use File::Copy;
use File::Basename;
use File::Path qw(make_path);

# CTOR
#
sub new
{
	my $class = shift;
	my $args = shift;

	my $cwd = getcwd();

	my $self = bless( { podroot => slashify("$cwd/podroot") }, $class);
	$self->__scan($args);

	return $self;
}

sub getCount
{
	my $self = shift;
	
	return $self->{count};
}

sub getN2P
{
	my $self = shift;
	
	return $self->{n2p}; 	
}

sub getCoreN2P
{
	my $self = shift;
	
	return $self->{n2p}->{'1-core'}; 	
}

sub getScriptN2P
{
	my $self = shift;
	
	return $self->{n2p}->{'4-script'}; 	
}

sub getPragmaN2P
{
	my $self = shift;
	
	return $self->{n2p}->{'2-pragma'}; 	
}

sub getModuleN2P
{
	my $self = shift;
	
	return $self->{n2p}->{'3-module'}; 	
}

sub getPodRoot
{
	my $self = shift;
	
	return $self->{podroot};
}

sub __scan
{
	my $self = shift;
	my $args = shift;
	
	my @spinner = ('|', '/', '-', '\\', '-');
	my $spinnerPos = 0;
	my $showSpinner = sub
		{
			if (-t STDOUT && $args->isVerboseLevel(0) && !$args->isVerboseLevel(2))
			{
				print ".$spinner[$spinnerPos].\r";
				$spinnerPos++;
				$spinnerPos = 0 if $spinnerPos > $#spinner;
			}
		};
		
	my $cb = sub
		{
			my $p = shift;
			my $n = shift;
			
			if ($args->isVerboseLevel(3))
			{
				print "Scanning '$n' => '$p'...\n";
			}
			else
			{
				$showSpinner->();
			}
		};
	
	my $verbosity = 0;
	$verbosity++ if $args->isVerboseLevel(4);
	$verbosity++ if $args->isVerboseLevel(5);

	my $binSearch = Pod::Simple::Search->new()->inc(0)->laborious(1)->callback($cb)->verbose($verbosity);
	$binSearch->survey($args->getBinDirs());
	my $bin_n2p = $binSearch->name2path;
	my @scriptNames = keys(%$bin_n2p); 
		
	my $libSearch = Pod::Simple::Search->new()->inc(0)->callback($cb)->verbose($verbosity);
	$libSearch->survey($args->getLibDirs());
	my $lib_n2p = $libSearch->name2path();

	my (@coreNames, @pragmaNames, @moduleNames);
	foreach my $name (keys(%$lib_n2p))
	{
		if ($name =~ /^pods::perl/ || $name =~ /^README$/)
		{
			push(@coreNames, $name);
		}
		elsif ($name =~ /^[a-z]/ && $lib_n2p->{$name} =~ /\.pm$/)
		{
			push(@pragmaNames, $name);
		}
		else
		{
			push(@moduleNames, $name);
		}
	}

	@scriptNames = $args->includeScriptNames(@scriptNames);
	@coreNames = $args->includeCoreNames(@coreNames);
	@pragmaNames = $args->includePragmaNames(@pragmaNames);
	@moduleNames = $args->includeModuleNames(@moduleNames);

	print "Preparing pod tree\n" if $args->isVerboseLevel(1);
		
	my %n2p;
	foreach my $name (@scriptNames)
	{
		my $type = '4-script';
		my $p = $bin_n2p->{$name};
		my $names = [ $name ];
		my $podfiles = $self->__copy($args, $names, $p, $type);
		$showSpinner->();
		my $ra = $n2p{$type} || [];
		push(@$ra, { names => $names, infile => $p, podfiles => $podfiles });
		$n2p{$type} = $ra; 
	}
	
	foreach my $name (@coreNames)
	{
		my $type = '1-core';
		my $alias = $name;
		$alias =~ s/^pods:://;
		my $p = $lib_n2p->{$name};
		my $names = [ $alias, $name ];
		my $podfiles = $self->__copy($args, $names, $p, $type);
		$showSpinner->();
		my $ra = $n2p{$type} || [];
		push(@$ra, { names => $names, infile => $p, podfiles => $podfiles });
		$n2p{$type} = $ra; 
	}
	
	foreach my $name (@pragmaNames)
	{
		my $type = '2-pragma';
		my $p = $lib_n2p->{$name};
		my $names = [ $name ];
		my $podfiles = $self->__copy($args, $names, $p, $type);
		$showSpinner->();
		my $ra = $n2p{$type} || [];
		push(@$ra, { names => $names, infile => $p, podfiles => $podfiles });
		$n2p{$type} = $ra; 
	}
	
	foreach my $name (@moduleNames)
	{
		my $type = '3-module';
		my $p = $lib_n2p->{$name};
		my $names = [ $name ];
		my $podfiles = $self->__copy($args, $names, $p, $type);
		$showSpinner->();
		my $ra = $n2p{$type} || [];
		push(@$ra, { names => $names, infile => $p, podfiles => $podfiles });
		$n2p{$type} = $ra; 
	}

	$self->{n2p} = \%n2p;
	
	$self->{count} = scalar(@scriptNames) + scalar(@coreNames) + scalar(@pragmaNames) + scalar(@moduleNames);
}

sub __copy
{
	my $self = shift;
	my $args = shift;
	my $names = shift;
	my $infile = shift;
	my $typeRoot = shift;

	my @podfiles;
	foreach my $name (@$names)
	{
		my $podname = $name;
		$podname =~ s#::#/#g;
		my $outfile = slashify("$self->{podroot}/$typeRoot/$podname.pod");
		push(@podfiles, $outfile);
	
		my $mtimeInfile = (stat($infile))[9];
		my $mtimeOutfile = -e $outfile ? (stat($outfile))[9] : 0; 
	
		if ($mtimeInfile > $mtimeOutfile)
		{
			my $outfileDir = dirname($outfile);
			(!-d $outfileDir ? make_path($outfileDir) : 1) || die ("Failed to create directory '$outfileDir': $!\n");
			copy($infile, $outfile) || die("Failed to copy $infile => $outfile: $!\n");
			utime($mtimeInfile, $mtimeInfile, $outfile);
		}
		
		print "Copied '$infile' => '$outfile'\n" if $args->isVerboseLevel(3);
	}
	
	return \@podfiles;
}

1;
