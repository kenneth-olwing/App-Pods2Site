package App::Pods2Site::SiteBuilder;

use strict;
use warnings;

use App::Pods2Site::Util qw(slashify readData writeData);
#
#use File::Basename;
#use File::Copy;
#use File::Path qw(make_path);
#use Pod::Html;
#use File::Slurp qw(write_file read_file);
#use JSON;

# CTOR
#
sub new
{
	my $class = shift;
	my $args = shift;
	my $pod2html = shift;
	my $css = shift;

	my $self = bless( {}, $class );

	$self->__updateMain($args, $css);
	$self->__updateHeader($args, $css);
	$self->__updateTOC($args, $css, $pod2html);
	$self->__updateIndex($args, $css);

	return $self;
}

# PRIVATE
#

sub __updateMain
{
	my $self = shift;
	my $args = shift;
	my $css = shift;

	my $z = slashify($0);
	my $builtBy = "<p><strong>This site built using:</strong><br/>";
	$builtBy .= "&emsp;$z ($App::Pods2Site::VERSION)<br/>";
	$builtBy .= "&emsp;$^X<br/>\n";
	$builtBy .= "</p>\n";
	
	my $scannedLocations = '';
	$scannedLocations .= "&emsp;$_<br/>" foreach ($args->getBinDirs(), $args->getLibDirs());
	$scannedLocations = "<p><strong>Scanned locations:</strong><br/>$scannedLocations</p>\n";
	
	my $coreQuery = $args->getFilter('core')->getQuery() || '';
	$coreQuery = "<p><strong>Core query:</strong><br/>&emsp;$coreQuery</br></p>" if $coreQuery;
	my $scriptQuery = $args->getFilter('script')->getQuery() || '';
	$scriptQuery = "<p><strong>Script query:</strong><br/>&emsp;$scriptQuery</br></p>" if $scriptQuery;
	my $pragmaQuery = $args->getFilter('pragma')->getQuery() || '';
	$pragmaQuery = "<p><strong>Pragma query:</strong><br/>&emsp;$pragmaQuery</br></p>" if $pragmaQuery;
	my $moduleQuery = $args->getFilter('module')->getQuery() || '';
	$moduleQuery = "<p><strong>Module query:</strong><br/>&emsp;$moduleQuery</br></p>" if $moduleQuery;
	
	my $actualCSS = $args->getCSS() || '';
	$actualCSS = "<p><strong>CSS:</strong><br/>&emsp;$actualCSS<br/></p>" if $actualCSS;
	
	my $sitedir = $args->getSiteDir();
	my $savedTS = readData($sitedir, 'timestamps') || [];
	push(@$savedTS, time());
	writeData($sitedir, 'timestamps', $savedTS);
	
	my $createdUpdated = '';
	$createdUpdated .= ('&emsp;' . localtime($_) . "<br/>\n") foreach (@$savedTS);
	$createdUpdated = "<p><strong>Created/Updated:</strong><br/>$createdUpdated</p>\n";
	
	my $stylesheet = $css ? qq(<link href="$css" rel="stylesheet"/>\n) : '';

	my $mainContent = <<MAIN;
<!DOCTYPE html>
<html>

	<head>
		<title>pods2site main</title>
		<meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
		$stylesheet
	</head>
		
	<body>
$builtBy
$scannedLocations
$coreQuery
$scriptQuery
$pragmaQuery
$moduleQuery
$actualCSS
$createdUpdated
	</body>
	
</html>
MAIN

	my $mainFile = slashify("$sitedir/main.html");
	die("Failed to write '$mainFile': $!") unless $self->__writeFile($mainFile, $mainContent);
	
	print "Wrote main as '$mainFile'\n" if $args->isVerboseLevel(2);
}

sub __updateHeader
{
	my $self = shift;
	my $args = shift;
	my $css = shift;

	my $stylesheet = $css ? qq(<link href="$css" rel="stylesheet"/>\n) : '';
		
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

	my $sitedir = $args->getSiteDir();
	my $headerFile = slashify("$sitedir/header.html");
	die("Failed to write '$headerFile': $!") unless $self->__writeFile($headerFile, $headerContent);
	
	print "Wrote header as '$headerFile'\n" if $args->isVerboseLevel(2);
}

sub __updateTOC
{
	my $self = shift;
	my $args = shift;
	my $css = shift;
	my $pod2html = shift;

	my $sitedir = $args->getSiteDir();

	my $s2n2h = $pod2html->getS2N2H();
	
	my $coren2h = $s2n2h->{core};
	my $scriptn2h = $s2n2h->{script};
	my $pragman2h = $s2n2h->{pragma};
	my $modulen2h = $s2n2h->{module};

	# the core toc is flat, and first
	#
	my $core = '';
	foreach my $n (sort(keys(%$coren2h)))
	{
		my $p = $coren2h->{$n};
		$p =~ s#\Q$sitedir\E.##;
		$p = slashify($p, '/');
		$core .= qq(<a href="$p" target="main_frame">$n</a><br/>\n);
	}
	chomp($core);
	$core = qq(<strong>Core</strong><br/><br/>\n$core<br/><hr/>) if $core;

	# common sub to handle the other categories
	#
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
					$p =~ s#\Q$sitedir\E.##;
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

	my $stylesheet = $css ? qq(<link href="$css" rel="stylesheet"/>\n) : '';
		
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

	my $tocFile = slashify("$sitedir/toc.html");
	die("Failed to write '$tocFile': $!") unless $self->__writeFile($tocFile, $tocContent);
	
	print "Wrote TOC as '$tocFile'\n" if $args->isVerboseLevel(2);
}

sub __updateIndex
{
	my $self = shift;
	my $args = shift;
	my $css = shift;

	my $stylesheet = $css ? qq(<link href="$css" rel="stylesheet"/>\n) : '';
		
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

	my $sitedir = $args->getSiteDir();
	my $indexFile = slashify("$sitedir/index.html");
	die("Failed to write '$indexFile': $!") unless $self->__writeFile($indexFile, $indexContent);
	
	print "Wrote index as '$indexFile'\n" if $args->isVerboseLevel(2);
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

1;
