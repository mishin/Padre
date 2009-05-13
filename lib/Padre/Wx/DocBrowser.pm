package Padre::Wx::DocBrowser;

use 5.008;
use strict;
use warnings;
use URI                   ();
use Encode                ();
use Scalar::Util          ();
use Class::Autouse        ();
use Padre::Wx             ();
use Padre::Wx::HtmlWindow ();
use Scalar::Util          ();
use Params::Util qw( _INSTANCE _INVOCANT _CLASSISA );
use Padre::Wx::AuiManager   ();
use Padre::Task::DocBrowser ();

our $VERSION = '0.35';
our @ISA     = 'Wx::Frame';

use Class::XSAccessor accessors => {
	notebook => 'notebook',
	provider => 'provider',
};

our %VIEW = (
	'text/xhtml'  => 'Padre::Wx::HtmlWindow',
	'text/html'   => 'Padre::Wx::HtmlWindow',
	'text/x-html' => 'Padre::Wx::HtmlWindow',
);

=pod

=head1 NAME

Padre::Wx::DocBrowser - Wx front-end for Padre::DocBrowser

=head1 Welcome to Padre DocBrowser

Padre::Wx::DocBrowser ( Wx::Frame )

=head1 DESCRIPTION

User interface for Padre::DocBrowser. 

=head1 METHODS

=head2 new

Constructor , see L<Wx::Frame>

=head2 help

Accepts a string, L<URI> or L<Padre::Document> and attempts to render 
documentation for such in a new AuiNoteBook tab. Links matching a scheme 
accepted by L<Padre::DocBrowser> will (when clicked) be resolved and 
displayed in a new tab.

=head2 show

TO BE COMPLETED


=head1 SEE ALSO

L<Padre::DocBrowser> L<Padre::Task::DocBrowser>

=cut

sub new {
	my ($class) = @_;

	my $self = $class->SUPER::new(
		undef,
		-1,
		'DocBrowser',
		Wx::wxDefaultPosition,
		[ 750, 700 ],
	);

	$self->{provider} = Padre::DocBrowser->new;

	my $top_s = Wx::BoxSizer->new(Wx::wxVERTICAL);
	my $but_s = Wx::BoxSizer->new(Wx::wxHORIZONTAL);

	my $notebook = Wx::AuiNotebook->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxAUI_NB_DEFAULT_STYLE
	);
	$self->notebook($notebook);

	my $entry = Wx::TextCtrl->new(
		$self, -1,
		'search terms..',
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTE_PROCESS_ENTER
	);

	Wx::Event::EVT_TEXT_ENTER(
		$self, $entry,
		sub {
			$self->on_search_text_enter($entry);
		}
	);

	my $label = Wx::StaticText->new(
		$self,                 -1, 'Search',
		Wx::wxDefaultPosition, Wx::wxDefaultSize,
		Wx::wxALIGN_RIGHT
	);
	$but_s->Add( $label, 2, Wx::wxALIGN_RIGHT | Wx::wxALIGN_CENTER_VERTICAL );
	$but_s->Add( $entry, 1, Wx::wxALIGN_RIGHT | Wx::wxALIGN_CENTER_VERTICAL );

	$top_s->Add( $but_s,    0, Wx::wxEXPAND );
	$top_s->Add( $notebook, 1, Wx::wxGROW );
	$self->SetSizer($top_s);
	$self->SetAutoLayout(1);
	#$self->_setup_welcome;

	return $self;
}

# Bad - this looks like a virtual, really a eventhandler
sub OnLinkClicked {
	my ( $self, $event ) = @_;
	my $htmlinfo = $event->GetLinkInfo;
	my $href     = $htmlinfo->GetHref;

	my $uri    = URI->new($href);
	my $scheme = $uri->scheme;
	if ( $self->provider->accept($scheme) ) {
		$self->help($uri);
	} else {
		Padre::Wx::LaunchDefaultBrowser($uri);
	}

}

sub on_search_text_enter {
	my ( $self, $event ) = @_;
	my $text = $event->GetValue;
	$self->help($text);

}

# Compat with old PodFrame help ?
sub show {
	shift->help(@_);
}

sub help {
	my ( $self, $query, %hints ) = @_;
	$query = $self->padre2docbrowser( $query )
		if ( _CLASSISA( ref $query ,'Padre::Document') );
	if ( _INVOCANT($query) && $query->can('mimetype') ) {
		#$self->debug( "Help from mimetype, " . $query->mimetype );
		my $task = Padre::Task::DocBrowser->new(
			document => $query, type => 'docs',
			main_thread_only => sub { $self->display( $_[0], $query ) },
		);
		$task->schedule;
		return 1;
	} elsif ( defined $query ) {
		#$self->debug("resolve '$query'");
		my $task = Padre::Task::DocBrowser->new(
			document => $query, type => 'resolve',
			main_thread_only => sub { $self->help( $_[0], referrer => $query ) }
		);
		$task->schedule;
		return 1;
	} else {
		$self->not_found( $hints{referrer} );
	}
}

sub ResolveRef {
	my ( $self, $ref ) = @_;
	my $task = Padre::Task::DocBrowser->new(
		document => $ref, type => 'resolve',
		main_thread_only => sub { $self->display( $_[0], $ref ) }
	);
	$task->schedule;

}

# FIXME , add our own output panel
sub debug {
	Padre->ide->wx->main->output->AppendText( $_[1] . $/ );
}

sub display {
	my ( $self, $docs, $query ) = @_;
	if ( _INSTANCE( $docs, 'Padre::DocBrowser::document' ) ) {
		#$self->debug(
		#	sprintf(
		#		"Display %s results of query %s",
		#		$docs->mimetype, $query
		#	)
		#);
		my $task = Padre::Task::DocBrowser->new(
			document => $docs, type => 'browse',
			main_thread_only => sub { $self->ShowPage( shift, $query ) }
		);
		$task->schedule;
	} elsif ( _INSTANCE( $query, 'Padre::DocBrowser::document' ) ) {
		die;
		#warn "TRY 2 render the query instead";
		my $task = Padre::Task::DocBrowser->new(
			document => $query, type => 'browse',
			main_thread_only => sub { $self->ShowPage( shift || $query, $query ) }
		);
		$task->schedule;
	}

}

sub ShowPage {
	my ( $self, $docs, $query ) = @_;

	unless ( _INSTANCE( $docs, 'Padre::DocBrowser::document' ) ) {
		return $self->not_found($query);
	}

	my $title = 'Untitled';
	my $mime  = 'text/xhtml';

	if ( _INSTANCE( $query, 'Padre::DocBrowser::document' ) ) {
		$title = $query->title;
	} else {
		$title = $docs->title;
	}

	my $total_pages = $self->notebook->GetPageCount;
	my @opened;
	my $i=0;
	while ( $i < $total_pages) {
		my $page = $self->notebook->GetPage($i);
		push @opened , {page=>$page,index=>$i} 
		    if $self->notebook->GetPageText($i) eq $title;
		$i++;
	}
	if (my $last = pop @opened) {
		$last->{page}->SetPage( $docs->body );
		$self->notebook->SetSelection(
			$last->{index}
		);
	}
	else {
		my $page = $self->NewPage( $docs->mimetype, $title );
		$page->SetPage( $docs->body );
	}
}

sub NewPage {
	my ( $self, $mime, $title ) = @_;
	my $page = eval {
		if ( exists $VIEW{$mime} )
		{
			Class::Autouse->autouse( $VIEW{$mime} );
			my $panel = $VIEW{$mime}->new($self);
			Wx::Event::EVT_HTML_LINK_CLICKED( $self, $panel, \&OnLinkClicked );
			$self->notebook->AddPage( $panel, $title, 1 );
			$panel;
		} else {
			$self->debug("DocBrowser: no viewer for $mime");
		}
	};

	$self->debug($@) if $@;
	return $page;

}

sub padre2docbrowser {
	my ($class,$padredoc) = @_;
	my $doc = Padre::DocBrowser::document->new(
		mimetype => $padredoc->get_mimetype,
		title    => $padredoc->get_title,
		filename => $padredoc->filename,
	);
	$doc->body( Encode::encode( 'utf8',
		$padredoc->{original_content} 
		)
	);
	return $doc;
}

sub not_found {
	my ( $self, $query ) = @_;
	my $html = qq|
<html><body>
<h1>Not Found</h1>
<p>Could not find documentation for
<pre>$query</pre>
</p>
</body>
</html>
|;
	my $frame = Padre::Wx::HtmlWindow->new($self);
	$self->notebook->AddPage( $frame, 'Not Found', 1 );
	$frame->SetPage($html);

}


1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

