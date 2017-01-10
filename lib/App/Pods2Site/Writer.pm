package App::Pods2Site::Writer;

use strict;
use warnings;

use App::Pods2Site::Util qw(slashify);

use File::Basename;
use File::Copy;
use File::Path qw(make_path);
use Pod::Html;
use File::Slurp qw(write_file read_file);
use JSON;

# CTOR
#
sub new
{
	my $class = shift;
	my $args = shift;
	my $podFinder = shift;

	my $self = bless
				(
					{
						written => 0,
						json => JSON->new()->utf8()->pretty()->canonical(),
					},
					$class
				);

	my $tsfile = $args->getOutDir() . '/' . $self->__persistFileName();
	$self->{ts} = (-f $tsfile) ? $self->__readTs($tsfile) : [];
	push(@{$self->{ts}}, time());
	$self->__writeTs($tsfile, $self->{ts});

	$self->__updateCSS($args);
	$self->__updatePOD2HTML($args, $podFinder);
	$self->__updateHeader($args);
	$self->__updateMain($args);
	$self->__updateTOC($args);
	$self->__updateIndex($args);

	return $self;
}

sub getWritten
{
	my $self = shift;
	
	return $self->{written};
}

# PRIVATE
#

sub __updateCSS
{
	my $self = shift;
	my $args = shift;
	
	my $incss = $args->getCSS();
	if ($incss)
	{
		my $outdir = $args->getOutDir();
		my $bn = basename($incss);
		my $outcss = slashify("$outdir/$bn");
		my $mtimeIn = (stat($incss))[9];
		my $mtimeOut = -e $outcss ? (stat($outcss))[9] : 0; 

		if ($mtimeIn > $mtimeOut)
		{
			copy($incss, $outcss) || die("Failed to copy $incss => $outcss: $!\n");
			print "Copied CSS '$incss' => '$outcss'\n" if $args->isVerboseLevel(1);
		}
		else
		{
			print "Skipping uptodate CSS '$outcss'\n" if $args->isVerboseLevel(1);
		}
		
		$self->{css} = $bn;
	}
}

sub __updatePOD2HTML
{
	my $self = shift;
	my $args = shift;
	my $podFinder = shift;
	
	my $n2p = $podFinder->getN2P();
	my @sections = sort(keys(%$n2p));

	my $podroot = $podFinder->getPodRoot();
	my $podpath = join(':', @sections);

	my @spinner = ('|', '/', '-', '\\', '-');
	my $spinnerPos = 0;

	my %n2h;
	foreach my $section (@sections)
	{
		foreach my $podinfo (@{$n2p->{$section}})
		{
			foreach my $podfile (@{$podinfo->{podfiles}})
			{
				my $outfile = $podfile;
				$outfile =~ s/^\Q$podroot\E.//;
				$outfile =~ s/\.[^.]+$//;
				$outfile = slashify($outfile, '/');
				
				my $htmlroot = ('..' x ($outfile =~ tr#/##)) || '.';
				$htmlroot =~ s#\.\.(?=\.)#../#g;
				
				my $relOutFile = "GEN/$outfile.html";
				$outfile = slashify($args->getOutDir() . "/$relOutFile");
				
				my $shortSec = $section;
				$shortSec =~ s/^\d-(.+)/$1/;
				$n2h{$shortSec}->{$podinfo->{names}->[0]} = $outfile;

				if (!-e $outfile || (stat($podfile))[9] > (stat($outfile))[9])
				{
					if ($args->isVerboseLevel(2))
					{
						print "Generating '$outfile'...\n";
					}
					elsif (-t STDOUT && $args->isVerboseLevel(0) && !$args->isVerboseLevel(2))
					{
						print ".$spinner[$spinnerPos].\r";
						$spinnerPos++;
						$spinnerPos = 0 if $spinnerPos > $#spinner;
					}

					my $outfileDir = dirname($outfile);
					(!-d $outfileDir ? make_path($outfileDir) : 1) || die ("Failed to create directory '$outfileDir': $!\n");
					my @p2hargs =
						(
							"--infile=$podfile",
							"--outfile=$outfile",
							"--podroot=$podroot",
							"--podpath=$podpath",
							"--htmlroot=$htmlroot"
						);
					my $css = $self->{css};
					push(@p2hargs, "--css=$htmlroot/../$css") if $css;
					if (!$args->isVerboseLevel(2))
					{
						push(@p2hargs, '--quiet');
					}
					else
					{
						push(@p2hargs, '--verbose') if $args->isVerboseLevel(3);
					}
					pod2html(@p2hargs);

					$self->{written}++;
				}
				else
				{
					if ($args->isVerboseLevel(1))
					{
						print "Skipping uptodate '$outfile'\n";
					}
					elsif ($args->isVerboseLevel(0) && -t STDOUT)
					{
						print ".$spinner[$spinnerPos].\r";
						$spinnerPos++;
						$spinnerPos = 0 if $spinnerPos > $#spinner;
					}
				}
			}
		}
	}
	
	$self->{n2h} = \%n2h;
}

sub __updateHeader
{
	my $self = shift;
	my $args = shift;

	my $outdir = $args->getOutDir();

	my $stylesheet = $self->{css} ? qq(<link href="$self->{css}" rel="stylesheet"/>\n) : '';
		
	my $headerContent = <<MAIN;
<!DOCTYPE html>
<html>

	<head>
		<title>pods2site header</title>
		<meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
		$stylesheet
	</head>
		
	<body>
		<h2><a href="main.html" target="main_frame">Pods2Site - Perl documentation from pods to html</a></h2>
	</body>
	
</html>
MAIN

	my $headerFile = slashify("$outdir/header.html");
	die("Failed to write '$headerFile': $!") unless $self->__writeFile($headerFile, $headerContent);
	
	print "Wrote header as '$headerFile'\n" if $args->isVerboseLevel(1);
}

sub __updateMain
{
	my $self = shift;
	my $args = shift;

	my $ver = $args->getVersion();

	my $scannedLocations = '';
	$scannedLocations .= "&emsp;$_<br/>" foreach ($args->getBinDirs(), $args->getLibDirs());
	
	my $coreQuery = $args->getIncludeCoreNamesText() || '';
	$coreQuery = "<p><strong>Core query:</strong><br/>&emsp;$coreQuery</br></p>" if $coreQuery;
	my $scriptQuery = $args->getIncludeScriptNamesText() || '';
	$scriptQuery = "<p><strong>Script query:</strong><br/>&emsp;$scriptQuery</br></p>" if $scriptQuery;
	my $pragmaQuery = $args->getIncludePragmaNamesText() || '';
	$pragmaQuery = "<p><strong>Pragma query:</strong><br/>&emsp;$pragmaQuery</br></p>" if $pragmaQuery;
	my $moduleQuery = $args->getIncludeModuleNamesText() || '';
	$moduleQuery = "<p><strong>Module query:</strong><br/>&emsp;$moduleQuery</br></p>" if $moduleQuery;
	
	my $actualCSS = $args->getCSS() || '';
	$actualCSS = "<p><strong>CSS:</strong><br/>&emsp;$actualCSS<br/></p>" if $actualCSS;
	
	my $createdUpdated = '';
	$createdUpdated .= ('&emsp;' . localtime($_) . "<br/>\n") foreach (@{$self->{ts}});
	
	my $stylesheet = $self->{css} ? qq(<link href="$self->{css}" rel="stylesheet"/>\n) : '';

	my $mainContent = <<MAIN;
<!DOCTYPE html>
<html>

	<head>
		<title>pods2site main</title>
		<meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
		$stylesheet
	</head>
		
	<body>
		<p>
			<strong>This site built using:</strong><br/>
			&emsp;$0 ($ver)<br/>
			&emsp;$^X<br/>
		</p>
		
		<p>
			<strong>Scanned locations:</strong><br/>
$scannedLocations
		</p>
		
		$coreQuery
		
		$scriptQuery
		
		$pragmaQuery
		
		$moduleQuery
		
		$actualCSS
		
		<p>
			<strong>Created/Updated:</strong><br/>
$createdUpdated
		</p>
		
	</body>
	
</html>
MAIN

	my $outdir = $args->getOutDir();
	my $mainFile = slashify("$outdir/main.html");
	die("Failed to write '$mainFile': $!") unless $self->__writeFile($mainFile, $mainContent);
	
	print "Wrote main as '$mainFile'\n" if $args->isVerboseLevel(1);
}

sub __updateTOC
{
	my $self = shift;
	my $args = shift;

	my $outdir = $args->getOutDir();

	my $coren2h = $self->{n2h}->{core};
	my $scriptn2h = $self->{n2h}->{script};
	my $pragman2h = $self->{n2h}->{pragma};
	my $modulen2h = $self->{n2h}->{module};

	my $core = '';
	foreach my $n (sort(keys(%$coren2h)))
	{
		my $p = $coren2h->{$n};
		$p =~ s#\Q$outdir\E.##;
		$p = slashify($p, '/');
		$core .= qq(<a href="$p" target="main_frame">$n</a><br/>\n);
	}
	chomp($core);
	$core = qq(<strong>Core</strong><br/><br/>\n$core<br/><hr/>) if $core;

	my $genrefs;
	$genrefs = sub
		{
			my $ref = shift;
			my $n2h = shift;
			my $treeloc = shift;
			my $depth = shift || 0;
			my $n = shift;
			my $np = shift;

			my $r = '';
			if ($n)
			{
				$r = "${n}::";
				$$ref .= ('&emsp;' x ($depth - 1)) if $depth > 1;
				my $p = $n2h->{$n};
				if ($p)
				{
					$p =~ s#\Q$outdir\E.##;
					$p = slashify($p, '/');
					$$ref .= qq(<a href="$p" target="main_frame">$np</a><br/>\n);
				}
				else
				{
					$$ref .= qq($np<br/>\n);
				}
			}
			foreach my $subnp (sort { lc($a) cmp lc($b) } (keys(%$treeloc)))
			{
				my $subn = "$r$subnp";
				next if $coren2h->{$subnp};
				
				$depth++;
				$genrefs->($ref, $n2h, $treeloc->{$subnp}, $depth, $subn, $subnp);
				$depth--;
			}
		};
	
	my $script = '';
	my %scripttree;
	foreach my $name (keys(%$scriptn2h))
	{
		my $treeloc = \%scripttree;
		for my $level (split(/::/, $name))
		{
			$treeloc->{$level} = {} unless exists($treeloc->{$level});
			$treeloc = $treeloc->{$level};
		}
	}
	$genrefs->(\$script, $scriptn2h, \%scripttree);
	chomp($script);
	$script = qq(<strong>Scripts</strong><br/><br/>\n$script<br/><hr/>) if $script;

	my %pragmatree;
	foreach my $name (keys(%$pragman2h))
	{
		my $treeloc = \%pragmatree;
		for my $level (split(/::/, $name))
		{
			$treeloc->{$level} = {} unless exists($treeloc->{$level});
			$treeloc = $treeloc->{$level};
		}
	}
	my $pragma = '';
	$genrefs->(\$pragma, $pragman2h, \%pragmatree);
	chomp($pragma);
	$pragma = qq(<strong>Pragmas</strong><br/><br/>\n$pragma<br/><hr/>) if $pragma;

	my %modtree;
	foreach my $name (keys(%$modulen2h))
	{
		my $treeloc = \%modtree;
		for my $level (split(/::/, $name))
		{
			$treeloc->{$level} = {} unless exists($treeloc->{$level});
			$treeloc = $treeloc->{$level};
		}
	}
	my $module = '';
	$genrefs->(\$module, $modulen2h, \%modtree);
	chomp($module);
	$module = qq(<strong>Modules</strong><br/><br/>\n$module<br/><hr/>) if $module;

	my $stylesheet = $self->{css} ? qq(<link href="$self->{css}" rel="stylesheet"/>\n) : '';
		
	my $tocContent = <<TOC;
<!DOCTYPE html>
<html>

	<head>
		<title>pods2site toc</title>
		<meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
		$stylesheet
	</head>
		
	<body>
$core
$script
$pragma
$module
	</body>
	
</html>
TOC

	my $tocFile = slashify("$outdir/toc.html");
	die("Failed to write '$tocFile': $!") unless $self->__writeFile($tocFile, $tocContent);
	
	print "Wrote TOC as '$tocFile'\n" if $args->isVerboseLevel(1);
}

sub __updateIndex
{
	my $self = shift;
	my $args = shift;

	my $outdir = $args->getOutDir();

	my $stylesheet = $self->{css} ? qq(<link href="$self->{css}" rel="stylesheet"/>\n) : '';
		
	my $indexContent = <<INDEX;
<!DOCTYPE html>
<html>

	<head>
		<title>pods2site index</title>
		<meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
		$stylesheet
	</head>
		
	
	<frameset rows="10%,*">
		<frame src="header.html" name="header_frame" />
		<frameset cols="15%,*">
			<frame src="toc.html" name="toc_frame" />
			<frame src="main.html" name="main_frame" />
		</frameset>
	</frameset>

</html>
INDEX

	my $indexFile = slashify("$outdir/index.html");
	die("Failed to write '$indexFile': $!") unless $self->__writeFile($indexFile, $indexContent);
	
	print "Wrote index as '$indexFile'\n" if $args->isVerboseLevel(1);
}

sub __writeFile
{
	my $self = shift;
	my $file = shift;
	my $content = shift;

	open (my $fh, '>:encoding(UTF-8)', $file) or die("Failed to open '$file': $!\n");
	print $fh $content;
	close($fh);  
}

sub __persistFileName
{
	return '.pods2site-ts';
}

sub __writeTs
{
	my $self = shift;
	my $file = shift;
	my $ts = shift;
	
	write_file($file, $self->{json}->encode($ts)) || die("Failed to write '$file': $!\n");
}

sub __readTs
{
	my $self = shift;
	my $file = shift;
	
	my $txt = read_file($file) || die("Failed to read '$file': $!\n");
	
	return $self->{json}->decode($txt);
}

1;
