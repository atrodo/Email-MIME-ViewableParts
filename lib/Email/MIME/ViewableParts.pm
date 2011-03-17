package Email::MIME::ViewableParts;

use warnings;
use strict;
use Carp;
use Scalar::Util;
use List::Util qw/first/;

use Email::MIME;
use Email::MIME::ContentType;

use base qw( Exporter );
our @EXPORT_OK = qw/get_viewable_parts get_html_parts get_text_parts/;

=head1 NAME

Email::MIME::ViewableParts - The great new Email::MIME::ViewableParts!

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Email::MIME::ViewableParts;

    my $foo = Email::MIME::ViewableParts->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head2 function1

=cut

my $part_return = sub {
  my $part = shift;
  return $part;
};

# All of the mime parts we can handle, and the code to handle them
my @html_parts = qw(text/html);
my @text_parts = qw(text/plain message/delivery-status);

my %viewable_parts = (
  'text/html'               => $part_return,
  'text/plain'              => $part_return,
  'message/delivery-status' => $part_return,

  'multipart/mixed' => sub {
    my $part = shift;
    return get_parts( [ $part->parts ], @_ );
  },
  'multipart/alternative' => sub {
    my $part = shift;

    my @result;
    my @good_parts = get_parts( [ $part->parts ], @_ );

    my $preffred_parts = shift || [];
    my $all_parts      = shift || [];

    foreach my $p (@good_parts)
    {
      my $ct = decode_ct( $p->content_type );
      push @result, $p if ( first { $ct eq $_ } @$preffred_parts );
    }
    return @result if scalar @good_parts;

    foreach my $p (@good_parts)
    {
      my $ct = decode_ct( $p->content_type );
      push @result, $p if ( first { $ct eq $_ } @$all_parts );
    }
    return @result if scalar @good_parts;

    return @good_parts;
  },
  'multipart/related' => sub {
    my $part = shift;
    return get_parts( [ $part->parts ], @_ );
  },
);

sub decode_ct
{
  my $in_ct = shift;
  my $ct    = parse_content_type($in_ct);
  $ct = lc( $ct->{discrete} ) . '/' . lc( $ct->{composite} );
  return $ct;
}

sub get_parts
{
  my $parts = shift;

  my @result;

  if ( eval { $parts->isa("Email::MIME") } )
  {
    $parts = [ $parts->parts ];
  }

  croak "Invalid Arguments, an Email::MIME object or "
    . "an array of Email::MIME objects must be passed to get_parts"
    if ref $parts ne "ARRAY";

  foreach my $part (@$parts)
  {
    croak "All parts for get_parts must be Email::MIME objects"
      if ref $part ne "Email::MIME";

    my $ct       = decode_ct( $part->content_type );
    my $viewable = $viewable_parts{$ct};
    next unless defined $viewable;

    my @result_parts = $viewable->( $part, @_ );

    push @result, @result_parts;
  }

  return $result[0] if !wantarray;
  return @result;
}

sub add_viewable_part
{
  my $type        = shift;
  my $handle_part = shift;

  if ( !defined $handle_part )
  {
    $handle_part = $part_return;
  }

  croak "Invalid arguments, handle_part must be a coderef"
    if ( ref $handle_part ne "CODE" );

  if ( exists $viewable_parts{$type} )
  {
    croak "Cannot add $type, already a viewable parts"
      unless $handle_part == $viewable_parts{$type};

    # It has already been added with the same handler, so it's cool
    return;
  }

  $viewable_parts{$type} = $handle_part;

  return 1;
}

sub add_html_part
{
  my $type        = shift;
  my $handle_part = shift;

  add_viewable_part( $type, $handle_part );

  push @html_parts, $type;

  return @html_parts;
}

sub add_text_part
{
  my $type        = shift;
  my $handle_part = shift;

  add_viewable_part( $type, $handle_part );

  push @text_parts, $type;

  return @text_parts;
}

sub get_viewable_parts
{
  return get_parts(@_);
}

sub search_parts
{
  my $parts       = shift;
  my $valid_types = shift;

  my @result;

  foreach my $part (@$parts)
  {
    my $ct = decode_ct( $part->content_type );
    push @result, $part
      if ( first { $ct eq $_ } @$valid_types );
  }

  return @result;
}

sub get_html_parts
{
  my @all_parts = get_viewable_parts( [@_], \@html_parts, \@text_parts );

  return search_parts( \@all_parts, \@html_parts );
}

sub get_text_parts
{
  my @all_parts = get_viewable_parts( [@_], \@text_parts, \@html_parts );

  return search_parts( \@all_parts, \@text_parts );
}

=head1 AUTHOR

Jon Gentle, C<< <atrodo at atrodo.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-email-mime-viewableparts at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Email-MIME-ViewableParts>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Email::MIME::ViewableParts


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Email-MIME-ViewableParts>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Email-MIME-ViewableParts>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Email-MIME-ViewableParts>

=item * Search CPAN

L<http://search.cpan.org/dist/Email-MIME-ViewableParts/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2011 Jon Gentle, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;    # End of Email::MIME::ViewableParts
