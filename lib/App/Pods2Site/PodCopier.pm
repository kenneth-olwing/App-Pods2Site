package App::Pods2Site::PodCopier;

use strict;
use warnings;

use App::Pods2Site::Util qw(slashify createSpinner);

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
	my $podFinder = shift;

	my $cwd = getcwd();

	my $self = bless( { podroot => slashify("$cwd/podroot") }, $class);
	$self->__copyPods($args, $podFinder);

	return $self;
}

#sub getCount
#{
#	my $self = shift;
#	
#	return $self->{count};
#}
#
#sub getN2P
#{
#	my $self = shift;
#	
#	return $self->{n2p}; 	
#}
#
#sub getCoreN2P
#{
#	my $self = shift;
#	
#	return $self->{n2p}->{'1-core'}; 	
#}
#
#sub getScriptN2P
#{
#	my $self = shift;
#	
#	return $self->{n2p}->{'4-script'}; 	
#}
#
#sub getPragmaN2P
#{
#	my $self = shift;
#	
#	return $self->{n2p}->{'2-pragma'}; 	
#}
#
#sub getModuleN2P
#{
#	my $self = shift;
#	
#	return $self->{n2p}->{'3-module'}; 	
#}

sub getPodRoot
{
	my $self = shift;
	
	return $self->{podroot};
}

sub __copyPods
{
	my $self = shift;
	my $args = shift;
	my $podFinder = shift;

	# set up some progress feedback
	#
	my $spinner = createSpinner();
	
	my %scriptn2p = $podFinder->getScriptN2P();
	foreach my $name (keys(%scriptn2p))
	{
		my $type = '4-script';
#		my $p = $bin_n2p->{$name};
#		my $names = [ $name ];
#		my $podfiles = $self->__copy($args, $names, $p, $type);
#		$showSpinner->();
#		my $ra = $n2p{$type} || [];
#		push(@$ra, { names => $names, infile => $p, podfiles => $podfiles });
#		$n2p{$type} = $ra; 
	}
	
#	foreach my $name (@coreNames)
#	{
#		my $type = '1-core';
#		my $alias = $name;
#		$alias =~ s/^pods:://;
#		my $p = $lib_n2p->{$name};
#		my $names = [ $alias, $name ];
#		my $podfiles = $self->__copy($args, $names, $p, $type);
#		$showSpinner->();
#		my $ra = $n2p{$type} || [];
#		push(@$ra, { names => $names, infile => $p, podfiles => $podfiles });
#		$n2p{$type} = $ra; 
#	}
#	
#	foreach my $name (@pragmaNames)
#	{
#		my $type = '2-pragma';
#		my $p = $lib_n2p->{$name};
#		my $names = [ $name ];
#		my $podfiles = $self->__copy($args, $names, $p, $type);
#		$showSpinner->();
#		my $ra = $n2p{$type} || [];
#		push(@$ra, { names => $names, infile => $p, podfiles => $podfiles });
#		$n2p{$type} = $ra; 
#	}
#	
#	foreach my $name (@moduleNames)
#	{
#		my $type = '3-module';
#		my $p = $lib_n2p->{$name};
#		my $names = [ $name ];
#		my $podfiles = $self->__copy($args, $names, $p, $type);
#		$showSpinner->();
#		my $ra = $n2p{$type} || [];
#		push(@$ra, { names => $names, infile => $p, podfiles => $podfiles });
#		$n2p{$type} = $ra; 
#	}

#	$self->{n2p} = \%n2p;
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
