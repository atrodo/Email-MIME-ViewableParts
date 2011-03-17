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

Email::MIME::ViewableParts - Find human viewable parts in a MIME email

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

    use Email::MIME::ViewableParts qw/get_viewable_parts/;

    my $email = Email::MIME->new($msg);
    my @parts = get_viewable_parts($email);

    my @text_parts = Email::MIME::ViewableParts::get_text_parts($email);

=head1 DESCRIPTION

This takes Email::MIME objects and finds the parts that can be displayed
to a user.

It tries to mimic the decisions of which MIME part to show that an email
client would make.

=cut

our $part_return = sub {
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

    my $preferred_parts = shift || [];
    my $all_parts       = shift || [];

    foreach my $p (@good_parts)
    {
      my $ct = decode_ct( $p->content_type );
      push @result, $p if ( first { $ct eq $_ } @$preferred_parts );
    }
    return @result if scalar @good_parts;

    foreach my $p (@good_parts)
    {
      my $ct = decode_ct( $p->content_type );
      push @result, $p if ( first { $ct eq $_ } @$all_parts );
    }
    return @result if scalar @good_parts;

    return ();
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
  my $parts     = shift;
  my $preferred = shift;
  my $all_types = shift;

  if ( !defined $preferred && !defined $all_types )
  {
    $preferred = [ @html_parts, @text_parts ];
    $all_types = $preferred;
  }
  return get_parts( $parts, $preferred, $all_types );
}

sub _search_parts
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

  return _search_parts( \@all_parts, \@html_parts );
}

sub get_text_parts
{
  my @all_parts = get_viewable_parts( [@_], \@text_parts, \@html_parts );

  return _search_parts( \@all_parts, \@text_parts );
}

=head1 EXPORT

These are the functions that can be exported and consist of the most common
use cases

=head2 get_viewable_parts

Get any and all parts that we think are viewable.  By default, that list is:

=over

=item * text/html

=item * text/plain

=item * message/delivery-status (text)

=back

=head3 C<get_viewable_parts> parameters:

=over

=item * EmailMimeObject(s) (Required)

The first parameter must be either an Email::MIME object or an array ref of
Email::MIME objects.  If it is an Email::MIME object, it automatically
uses the parts of that object as the objects to operate on

=item * Preferred MIME types (Optional)

The second parameter is an array ref of mime type strings that represent the
mime types that you would prefer getting in multipart/alternative parts.
See the L</"Notes About multipart/alternative"> section below.

=item * Acceptable MIME types (Optional)

The third parameter is also an array ref of mime type strings that represent
the other mime types that you accept in the case of multipart/alternative
parts.

=back

If the last two parameters are not given, then by default, get_viewable_parts
will return all parts, including every viewable part in a
multipart/alternative part.

=head2 get_html_parts

Get the parts that are html.  If there is a multipart/alternative part that
does not have an html part but has a text part, it will give you the text part.
See the L</"Notes About multipart/alternative"> section below.

=head2 get_text_parts

Get the parts that are text.  See above about multipart/alternative parts.

=head1 FUNCTIONS

In addition, there are some more function available to adjust the functionality
of ViewableParts.

=head2 add_html_part

Add a mime type to the list of parts that are html. This will call
add_viewable_part so you must pass a handler.

=head2 add_text_part

Add a mime type to the list of parts that are text. This will call
add_viewable_part so you must pass a handler.

=head2 add_viewable_part

Add a new mime type to the list of mime that ViewableParts can handle. Two
parameters are passed:

=over

=item * MIME Type string

=item * Handler Coderef

=back

=head1 Handlers

If you want to extend Email::MIME::ViewableParts with new MIME types, you can
with handlers.  The handler is a coderef that returns all the parts in this
section that are viewable.

There are couple functions available that will help you discover subparts.
They are documented below.

Chances are, you want to use C<$Email::MIME::ViewableParts::part_return>,
which will just return your part as is.

=head2 * decode_ct

This is a function to take a content type from an Email::MIME object and
return a normalized string representation of it.  This uses
L<Email::MIME::ContentType>.

=head2 * get_parts

This is the guts of L</get_viewable_parts>.  It accepts the same parameters
except all the parameters are required it will not attempt to guess what types
you want to accept.

=head1 Notes About multipart/alternative

One of the tricky parts of the choice of what MIME part to display is in
multipart/alternative.  The question is which one to choose since each part
is suppose to be equivalent.  That's why get_parts has a preferred and
acceptable lists.  If any part is a preferred type, it will be included in
the result.  If not, then it will look for acceptable parts.  All the parts
that are acceptable are returned.  If none are preferred or acceptable, nothing
will be returned.

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
