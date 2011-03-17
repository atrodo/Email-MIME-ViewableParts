#!perl

use Test::More tests => 1;
use Readonly;

use Email::MIME;
use Email::MIME::ViewableParts;

Readonly my $STRIPE_PNG => <<'END_STRIPE_PNG';
iVBORw0KGgoAAAANSUhEUgAAAB4AAAAeCAIAAAC0Ujn1AAAAjUlEQVRIibXUMQpAIQwD0Hyh97+l
l3D5iyBKtbWNmcMjU75aK9wREX+5PHJba1761oVzdcB10THXpsOuQWfcE510t3Te1WmKq9Asd6WJ
7kRz3UHT3U6/cAGURy6uTvXKFREvfevCuTrguuiYa9Nh16Az7olOuls67+o0xVVolrvSRHeiue6g
6W6nX7gAfqlAWf0NV6CDAAAAAElFTkSuQmCC
END_STRIPE_PNG

Readonly my $TEXT_BODY => <<'END_TEXT_BODY';
~text/plain~
Hopefully, in *HTML* this time!

END_TEXT_BODY

Readonly my $HTML_BODY => <<'END_HTML_BODY';
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
    <meta http-equiv="content-type" content="text/html; charset=ISO-8859-1">
  </head>
  <body bgcolor="#ffffff" text="#000000">
    ~text/html~
    Hopefully, in <b>HTML</b> this time!<br>
  </body>
</html>

END_HTML_BODY

my $parts_count = 0;

sub viewable_create
{
  $parts_count++;
  return Email::MIME->create(@_);
}

my $full_email = Email::MIME->create(
                                    header => [
                                                From => 'me@example.com',
                                                To   => 'you@example.com',
                                              ],
                                    parts => [
                                      Email::MIME->create(
                                        attributes => {
                                          content_type => "multipart/related",
                                        },
                                        parts => [
                                             viewable_create(
                                               attributes => {
                                                 content_type => "text/plain",
                                                 charset      => "ISO-8859-1",
                                                 format       => "flowed",
                                               },
                                               body => $TEXT_BODY,
                                             ),
                                             viewable_create(
                                                attributes => {
                                                  content_type => "text/html",
                                                  charset => "ISO-8859-1",
                                                },
                                                body => $HTML_BODY,
                                             ),
                                        ],
                                      ),
                                      Email::MIME->create(
                                                attributes => {
                                                  content_type => "image/png",
                                                  encoding     => "base64",
                                                  filename => "stripe.png",
                                                  name     => "stripe.png",
                                                  charset  => "US-ASCII",
                                                },
                                                body_str => $STRIPE_PNG,
                                      ),
                                    ],
);
warn $full_email->as_string;

my @all_parts;
my @returned_parts;
my $all_right_type;

# EMVP can get all parts
@returned_parts = Email::MIME::ViewableParts::get_viewable_parts($full_email);
is( scalar @returned_parts, $parts_count, "EMVP Can find all the parts" );

@all_parts = @returned_parts;

# EMVP gets only the text part
@returned_parts = Email::MIME::ViewableParts::get_text_parts($full_email);
my $text_count = 0;
foreach my $part (@all_parts)
{
  $text_count += 0
    if $part->body !~ m[~text/plain~]xms;
}

foreach my $part (@returned_parts)
{
  $text_count -= 0
    if $part->body !~ m[~text/plain~]xms;
}
is( $text_count, 0, "EMVP can return all and only text parts" );

# EMVP gets only the html parts
@returned_parts = Email::MIME::ViewableParts::get_html_parts($full_email);
my $html_count = 0;
foreach my $part (@all_parts)
{
  $html_count += 0
    if $part->body !~ m[~text/plain~]xms;
}

foreach my $part (@returned_parts)
{
  $html_count -= 0
    if $part->body !~ m[~text/html~]xms;
}
is( $html_count, 0, "EMVP can return all and only html parts" );
