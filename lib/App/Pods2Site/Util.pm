package App::Pods2Site::Util;

use strict;
use warnings;

our $IS_WINDOWS = $^O eq 'MSWin32'; 

use Exporter qw(import);
our @EXPORT_OK =
	qw
		(
			$IS_WINDOWS
			slashify
			readData
			writeData
			createSpinner
			writeUTF8File
			readUTF8File
		);

use JSON;

my $FILE_SEP = $IS_WINDOWS ? '\\' : '/';
my $DATAFILE = '.pods2site';
my $JSON = JSON->new()->utf8()->pretty()->canonical();
my @SPINNERPOSITIONS = ('|', '/', '-', '\\', '-');

# pass in a path and ensure it contains the native form of slash vs backslash
# (or force either one)
#
sub slashify
{
	my $s = shift;
	my $fsep = shift || $FILE_SEP;

	my $dblStart = $s =~ s#^[\\/]{2}##;
	$s =~ s#[/\\]+#$fsep#g;

	return $dblStart ? "$fsep$fsep$s" : $s;
}

sub writeData
{
	my $dir = shift;
	my $section = shift;
	my $data = shift;
	
	my $allData = readData($dir) || {};
	$allData->{$section} = $data;
	
	my $df = slashify("$dir/$DATAFILE");
	open (my $fh, '> :raw :bytes', $df) or die("Failed to open '$df': $!\n");
	print $fh $JSON->encode($allData);
	close($fh);  
}

sub readData
{
	my $dir = shift;
	my $section = shift;

	my $data;

	my $df = slashify("$dir/$DATAFILE");
	if (-f $df)
	{
		open (my $fh, '< :raw :bytes', $df) or die("Failed to open '$df': $!\n");
		my $buf;
		my $szExpected = -s $df;
		my $szRead = read($fh, $buf, -s $df);
		die("Failed to read from '$df': $!\n") unless ($szRead && $szRead == $szExpected); 
		close($fh);
		$data = $JSON->decode($buf);
		$data = $data->{$section} if $section;
	}

	return $data;
}

sub createSpinner
{
	my $args = shift;

	my $spinner = sub {};
	if (-t STDOUT && $args->isVerboseLevel(0) && !$args->isVerboseLevel(2))
	{
		my $pos = 0;
		$spinner = sub
			{
				print ".$SPINNERPOSITIONS[$pos++].\r";
				$pos = 0 if $pos > $#SPINNERPOSITIONS;
			};
	}
	
	return $spinner;
}

sub writeUTF8File
{
	my $file = shift;
	my $data = shift;
	
	open (my $fh, '> :encoding(UTF-8)', $file) or die("Failed to open '$file': $!\n");
	print $fh $data;
	close($fh);  
}

sub readUTF8File
{
	my $file = shift;
	
	open (my $fh, '< :encoding(UTF-8)', $file) or die("Failed to open '$file': $!\n");
	local $/ = undef;
	my $data = <$fh>;
	close($fh);  
	
	return $data;
}

1;
