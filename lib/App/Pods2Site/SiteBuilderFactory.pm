package App::Pods2Site::SiteBuilderFactory;

use strict;
use warnings;

my $STDSTYLE = 'basicframes';
my %VALIDSTYLES =
	(
		'basicframes' => 'App::Pods2Site::SiteBuilder::BasicFrames',
		'basicframeshtml5' => 'App::Pods2Site::SiteBuilder::BasicFramesHTML5',
	);
	
# CTOR
#
sub new
{
	my $class = shift;
	my $style = shift || ':std';

	my $self = bless( { style => $style }, $class );

	$self->__computeStyle($style);

	return $self;
}

sub getStyle
{
	my $self = shift;
	
	return $self->{style};
}

sub getRealStyle
{
	my $self = shift;
	
	return $self->{realstyle};
}

sub createSiteBuilder
{
	my $self = shift;
	
	eval "require $self->{sitebuilderclass}";
	 
	$self->{sitebuilderclass}->new($self->getRealStyle());
}

# PRIVATE
#

sub __computeStyle
{
	my $self = shift;
	my $style = shift;
	
	$style = $STDSTYLE if $style eq ':std';
	$self->{realstyle} = $style;

	my $siteBuilderClass = $VALIDSTYLES{$style};
	die("No such style: '$style' (available: " . join(',', keys(%VALIDSTYLES)) . ")\n") unless $siteBuilderClass;
	$self->{sitebuilderclass} = $siteBuilderClass; 
}

1;
