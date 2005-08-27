package JSAN::Shell2;

=pod

=head1 NAME

JSAN::Shell2 - JavaScript Archive Network (JSAN) Shell (2nd Generation)

=head1 DESCRIPTION

C<JSAN::Shell2> provides command handling and dispatch for the L<jsan2>
user application. It interprates these commands and provides the
appropriate instructions to the L<JSAN::Client> and L<JSAN::Transport>
APIs.

=head2 Why Do Another Shell So Soon?

The JavaScript Archive Network, like its predecessor CPAN, is a large
system with quite a number of different parts.

In an effort to have a usable repository up, running and usable as
quickly as possible, some systems (such as the JSAN shell) were built
with the understanding that they would be replaced by lighter, more
scalable and more comprehensive (but much slower to write) replacements
once they had time to catch up.

C<JSAN::Shell2> represents the rewrite of the end-user oriented shell
component, with L<JSAN::Client> providing the seperate and more general
programmatic client interface.

=head1 METHODS

=cut

use strict;
use Term::ReadLine ();
use Params::Util   '_IDENTIFIER';
use JSAN::Index;

use vars qw{$VERSION};
BEGIN {
	$VERSION = '2.00_01';
}





#####################################################################
# Constructor

sub new {
	my $class  = ref $_[0] ? ref shift : shift;
	my %params = @_;

	# Create the actual object
	my $self = bless {
		term   => $Term::ReadLine::Perl::term
			|| Term::ReadLine->new,
		prompt => 'jsan> ',
		}, $class;

	# Initialize JSAN::Transport (with default values for now)
	JSAN::Transport->init;

	$self;
}

sub term { $_[0]->{term} }

sub prompt { $_[0]->{prompt} }






#####################################################################
# JSAN::Shell2 Main Methods

sub run {
	my $self = shift;
	$self->execute('help motd');
	while (defined(my $cmd_line = $self->term->readline($self->prompt))) {
		$cmd_line = $self->_clean($cmd_line);
		next unless length($cmd_line);
		eval { $self->execute($cmd_line) };
		if ( $@ ) {
			warn "$@\n";
		} else {
			$self->term->addhistory($cmd_line);
		}
	}
}

# Execute a single command
sub execute {
	my ($self, $line) = @_;
	my %options = (
		force  => 0,
		);

	# Split and find the command
	my @words = split / /, $line;
	my $word  = shift(@words);
	my $cmd   = $self->resolve_command($word)
		or return $self->_show("Unknown command '$word'. Type 'help' for a list of commands");

	# Is the command implemented
	my $method = "command_$cmd";
	unless ( $self->can($method) ) {
		return $self->_show("The command '$cmd' is not currently implemented");
	}

	# Hand off to the specific command
	$options{params} = \@words;
	$self->$method( %options );
}





#####################################################################
# General Commands

sub command_quit {
	exit(0);
}

sub command_help {
	my $self   = shift;
	my %args   = @_;
	my @params = @{$args{params}};

	# Get the command to show help for
	my $command = $params[0] || 'commands';
	my $method  = "help_$command";

	return $self->can($method)
		? $self->_show($self->$method())
		: $self->_show("No help page for command '$command'");
}





#####################################################################
# Investigation

sub command_author {
	my $self   = shift;
	my %args   = @_;
	my @params = @{$args{params}};
	my $name   = lc _IDENTIFIER($params[0])
		or return $self->_show("Not a valid author identifier");

	# Find the author
	my $author = JSAN::Index::Author->retrieve( login => $name );
	unless ( $author ) {
		return $self->_show("Could not find the author '$name'");
	}

	$self->show_author( $author );
}

sub command_dist {
	my $self   = shift;
	my %args   = @_;
	my @params = @{$args{params}};
	my $name   = $params[0];

	# Find the author
	my $dist = JSAN::Index::Distribution->retrieve( name => $name );
	unless ( $dist ) {
		return $self->_show("Could not find the distribution '$name'");
	}

	$self->show_dist( $dist );
}

sub command_library {
	my $self   = shift;
	my %args   = @_;
	my @params = @{$args{params}};
	my $name   = $params[0];

	# Find the library
	my $library = JSAN::Index::Library->retrieve( name => $name );
	unless ( $library ) {
		return $self->_show("Could not find the library '$name'");
	}

	$self->show_library( $library );
}

sub show_author {
	my $self   = shift;
	my $author = shift;
	$self->_show(
		"Author ID = "  . $author->login,
		"    Name:    " . $author->name,
		"    Email:   " . $author->email,
		"    Website: " . $author->url,
		);
}

sub show_dist {
	my $self      = shift;
	my $dist      = shift;
	my $release   = $dist->latest_release;
	my $author    = $release->author;

	# Get the list of libraries in this release.
	# This only works because we are using the latest release.
	my @libraries =
		sort { $a->name cmp $b->name }
		JSAN::Index::Library->search( release => $release->id );

	# Find the max library name length and create the formatting string
	my $max = 0;
	foreach ( @libraries ) {
		next if length($_->name) <= $max;
		$max = length($_->name);
	}
	my $string = "    Library:  %-${max}s  %s";

	$self->_show(
		"Distribution   = " . $dist->name,
		"Latest Release = " . $release->source,
		"    Version:  "    . $release->version,
		"    Created:  "    . scalar(localtime($release->created)),
		"    Author:   "    . $author->login,
		"        Name:    " . $author->name,
		"        Email:   " . $author->email,
		"        Website: " . $author->url,
		map {
			sprintf( $string, $_->name, $_->version )
		} @libraries
		);
}

sub show_library {
	my $self    = shift;
	my $library = shift;
	my $release = $library->release;
	my $dist    = $release->distribution;
	my $author  = $release->author;

	# Get the list of libraries in this release.
	# This only works because we are using the latest release.
	my @libraries =
		sort { $a->name cmp $b->name }
		JSAN::Index::Library->search( release => $release->id );

	# Find the max library name length and create the formatting string
	my $max = 0;
	foreach ( @libraries ) {
		next if length($_->name) <= $max;
		$max = length($_->name);
	}
	my $string = "    Library:  %-${max}s  %s";

	$self->_show(
		"Library          = " . $library->name,
		"    Version: " . $library->version,
		"In Distribution  = " . $dist->name,
		"Latest Release   = " . $release->source,
		"    Version:  "      . $release->version,
		"    Created:  "      . scalar(localtime($release->created)),
		"    Author:   "      . $author->login,
		"        Name:    "   . $author->name,
		"        Email:   "   . $author->email,
		"        Website: "   . $author->url,
		map {
			sprintf( $string, $_->name, $_->version )
		} @libraries,
		);
}





#####################################################################
# Localisation and Content

# For a given string, find the command for it
my %COMMANDS_EN = (
	'quit'         => 'quit',
	'exit'         => 'quit',
	'q'            => 'quit',
	'help'         => 'help',
	'h'            => 'help',
	'?'            => 'help',
	'a'            => 'author',
	'author'       => 'author',
	'd'            => 'dist',
	'dist'         => 'dist',
	'distribution' => 'dist',
	'l'            => 'library',
	'lib'          => 'library',
	'library'      => 'library',
	);
sub resolve_command {
	$COMMANDS_EN{$_[1]};
}




sub help_usage { <<"END_HELP" }
Usage: cpan [-OPTIONS [-MORE_OPTIONS]] [--] [PROGRAM_COMMAND ...]

For more details run
        perldoc -F /usr/bin/cpan
END_HELP



sub help_motd { <<"END_HELP" }
jsan shell -- JSAN exploration and library installation (v$VERSION)
           -- Copyright 2005 Adam Kennedy. All rights reserved.
           -- Type 'help' for a summary of available commands.
END_HELP



sub help_commands { <<"END_HELP" }
   ------------------------------------------------------------
 | Display Information                                          |
 | ------------------------------------------------------------ |
 | command     | argument      | description                    |
 | ------------------------------------------------------------ |
 | a,author    | WORD          | about an author                |
 | d,dist      | WORD          | about a distribution           |
 | l,library   | WORD          | about a library                |
 | f,find      | SUBSTRING     | all matches from above         |
 | ------------------------------------------------------------ |
 | Download, Test, Install...                                   |
 | ------------------------------------------------------------ |
 | get         |               | download                       |
 | install     | WORD          | install (implies get)          |
 | readme      | WORD          | display the README file        |
 | ------------------------------------------------------------ |
 | Other                                                        |
 | ------------------------------------------------------------ |
 | h,help,?    |               | display this menu              |
 | h,help,?    | COMMAND       | command details                |
 | conf get    | OPTION        | get a config option            |
 | conf set    | OPTION, VALUE | set a config option            |
 | quit,q,exit |               | quit the jsan shell            |
   ------------------------------------------------------------
END_HELP





#####################################################################
# Support Methods

# Clean a single command
sub _clean {
	my ($self, $line) = @_;
	$line =~ s/\s+/ /s;
	$line =~ s/^\s+//s;
	$line =~ s/\s+$//s;
	$line;
}

# Print a single line to screen
sub _print {
	my $self = shift;
	while ( @_ ) {
		my $line = shift;
		chomp($line);
		print STDOUT "$line\n";
	}
	1;
}

# Print something with a leading and trailing blank line
sub _show {
	my $self = shift;
	$self->_print( '', @_, '' );
}

1;

=pod

=head1 AUTHORS

Adam Kennedy <F<adam@ali.as>>, L<http://ali.as>

Guts stolen from JSAN::Shell by Casey West <F<casey@geeknest.com>>

=head1 SEE ALSO

L<jsan2>, L<JSAN::Client>, L<http://openjsan.org>

=head1 COPYRIGHT

Copyright 2005 Adam Kennedy.  All rights reserved.
 
Parts copyright (c) 2005 Casey West.  All rights reserved.
  
This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
