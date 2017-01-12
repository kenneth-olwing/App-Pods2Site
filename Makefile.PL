use strict;
use warnings;

use ExtUtils::MakeMaker;

my $IS_WIN32 = $^O eq 'MSWin32';

my $downstream_requires =
	{
# @@TBD@@
	};
	
my $configure_requires =
	{
		%$downstream_requires,
		'ExtUtils::MakeMaker' => '7.12', 
	};

my $test_requires =
	{
# @@TBD@@
	};

my $eumm_understands_meta_merge = $ExtUtils::MakeMaker::VERSION ge '6.46';
my $eumm_understands_conf_and_test_requires_properly = $ExtUtils::MakeMaker::VERSION ge '7.12';

WriteMakefile(
    NAME             => 'App::Pods2Site',
    AUTHOR           => q{Kenneth Olwing <knth@cpan.org>},
    VERSION_FROM     => 'lib/App/Pods2Site.pm',
    ABSTRACT_FROM    => 'lib/App/Pods2Site.pod',
    LICENSE          => 'artistic_2',
    EXE_FILES         => [ 'script/pods2site' ],
	$eumm_understands_meta_merge
		? (
			META_MERGE =>
				{
					'meta-spec' =>
						{
							version => 2,
						},
					resources =>
						{
							repository =>
								{
									type => 'git',
									url => 'https://github.com/kenneth-olwing/App-Pods2Site.git',
									web => 'https://github.com/kenneth-olwing/App-Pods2Site'
								}
						}
				}
			)
		: (),
	$eumm_understands_conf_and_test_requires_properly
		? ( CONFIGURE_REQUIRES => $configure_requires, TEST_REQUIRES => $test_requires )
		: (),
	PREREQ_PM =>
		{
			$eumm_understands_conf_and_test_requires_properly
				? ()
				: ( %$configure_requires, %$test_requires ),
			'Grep::Query' => '1.004',
# @@TBD@@
		},
	dist  =>
		{
			$IS_WIN32 ? (TARFLAGS => '--mode=755 -cvf') : (),
			COMPRESS => 'gzip -9f',
			SUFFIX => 'gz',
			DIST_DEFAULT => 'alltest tardist'
		},
    clean => { FILES => 'App-Pods2Site-* *.tmp' },
	test => { RECURSIVE_TEST_FILES => 1 },
);

package MY;

sub postamble
{
	return <<'MAKE_FRAG';

XTEST_STANDARD_FILES = xt/standard/*.t
XTEST_AUTHOR_FILES = xt/author/*.t

# make test: runs all 't' tests (pre-provided by EUMM)
# make test_v: runs all 't' tests verbose
#
.PHONY : test_v

test_v : dynamic pure_all
	$(NOECHO) prove -lvr --merge $(TEST_FILES)

# make xtest: runs all 'xt' tests
# make xtest_v: runs all 'xt' tests verbose
#
.PHONY : xtest xtest_v

xtest : dynamic pure_all
	$(NOECHO) prove -lr --merge $(XTEST_STANDARD_FILES)

xtest_v : dynamic pure_all
	$(NOECHO) prove -lvr --merge $(XTEST_STANDARD_FILES)

# make authortest: runs all 'xt/author' tests
# make authortest_v: runs all 'xt/author' tests verbose
#
.PHONY : authortest authortest_v

authortest : dynamic pure_all
	$(NOECHO) prove -lr --merge $(XTEST_AUTHOR_FILES)

authortest_v : dynamic pure_all
	$(NOECHO) prove -lvr --merge $(XTEST_AUTHOR_FILES)

# make alltest: runs all tests
# make alltest_v: runs all tests verbose
#
.PHONY : alltest alltest_v

alltest : test xtest authortest
	$(NOECHO) $(NOOP)

alltest_v : test_v xtest_v authortest_v
	$(NOECHO) $(NOOP)

MAKE_FRAG
}
