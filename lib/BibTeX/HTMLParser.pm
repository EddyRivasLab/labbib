package BibTeX::HTMLParser;

use strict;
use warnings;
use parent qw(BibTeX::Parser);
use BibTeX::Parser::HTMLEntry;

sub _parse_next {
  my $self = shift;
  my $entry = $self->SUPER::_parse_next();
  if (ref $entry eq 'BibTeX::Parser::Entry') {
    $entry = bless $entry, 'BibTeX::Parser::HTMLEntry';
  }
  return $entry;
}

1;
