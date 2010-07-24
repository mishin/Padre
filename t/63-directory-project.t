#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;
use Test::NoWarnings;
use File::Spec                 ();
use Padre::Project::Perl       ();
use Padre::Wx::Directory::Path ();
use Padre::Wx::Directory::Task ();

# Locate the test project
my $root = File::Spec->catdir( 't', 'collection', 'Config-Tiny' );
my $project = new_ok(
	'Padre::Project::Perl' => [
		root => $root,
	]
);





######################################################################
# Scan a known tree via a project

SCOPE: {
	my $task = new_ok(
		'Padre::Wx::Directory::Task',
		[   project => $project,
			order   => 'first',
		]
	);
	ok( $task->run, '->run ok' );
	is( ref( $task->{model} ), 'ARRAY', '->{model} ok' );
	my @files = @{ $task->{model} };
	is( scalar( grep { !$_->isa('Padre::Wx::Directory::Path') } @files ), 0,
		'All files are Padre::Wx::Directory::Path objects',
	);
	is_deeply(
		[ map { $_->unix } @files ],
		[   qw{
				lib
				lib/Config
				lib/Config/Tiny.pm
				t
				t/01_compile.t
				t/02_main.t
				Changes
				Makefile.PL
				test.conf
				}
		],
		'Config-Tiny project contains expected files',
	);
}





######################################################################
# Repeat to test mixed-directory order

SCOPE: {
	my $task = new_ok(
		'Padre::Wx::Directory::Task',
		[   project => $project,
			order   => 'mixed',
		]
	);
	ok( $task->run, '->run ok' );
	is( ref( $task->{model} ), 'ARRAY', '->{model} ok' );
	my @files = @{ $task->{model} };
	is( scalar( grep { !$_->isa('Padre::Wx::Directory::Path') } @files ), 0,
		'All files are Padre::Wx::Directory::Path objects',
	);
	is_deeply(
		[ map { $_->unix } @files ],
		[   qw{
				Changes
				lib
				lib/Config
				lib/Config/Tiny.pm
				Makefile.PL
				t
				t/01_compile.t
				t/02_main.t
				test.conf
				}
		],
		'Config-Tiny project contains expected files',
	);
}
