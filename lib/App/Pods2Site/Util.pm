package App::Pods2Site::Util;

use strict;
use warnings;

our $IS_WINDOWS = $^O eq 'MSWin32'; 

use Exporter qw(import);
our @EXPORT_OK =
	qw
		(
			slashify
			isDirEmpty
			$IS_WINDOWS
		);

my $file_sep = $IS_WINDOWS ? '\\' : '/';

# pass in a path and ensure it contains the native form of slash vs backslash
# (or force either one)
#
sub slashify
{
	my $s = shift;
	my $fsep = shift || $file_sep;

	my $dblStart = $s =~ s#^[\\/]{2}##;
	$s =~ s#[/\\]+#$fsep#g;

	return $dblStart ? "$fsep$fsep$s" : $s;
}

sub isDirEmpty
{
	my $dir = shift;
	my %ignore = map { $_ => 1 } @{shift || []};
	
	opendir(my $dh, $dir) or die("Failed to opendir '$dir': $!\n");
	my @entries = grep(!/^\.\.?$/, readdir($dh));
	close($dh);
	
	foreach my $e (@entries)
	{
		return 0 unless $ignore{$e};
	}
	
	return 1;	
}

1;
