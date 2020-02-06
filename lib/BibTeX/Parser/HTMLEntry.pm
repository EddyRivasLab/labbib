package BibTeX::Parser::HTMLEntry;

use strict;
use warnings;
use parent qw(BibTeX::Parser::Entry);
use LaTeX::ToUnicode qw( convert );

sub doctypes {
  my $self = shift;
  return [qw(reprint.ps reprint.pdf preprint.pdf preprint.ps
   techreport.ps techreport.pdf phdthesis.pdf phdthesis.ps
   mastersthesis.pdf mastersthesis.ps)];
}

sub pubsdir {
  my ($self, $dir) = @_;
  if ($dir) {
    $self->{_pubsdir} = $dir;
  }
  return $self->{_pubsdir};
}

sub pubsurl {
  my ($self, $url) = @_;
  if ($url) {
    $self->{_pubsurl} = $url;
  }
  return $self->{_pubsurl};
}

sub root_url {
  my $self = shift;
  return $self->pubsurl || '/';
}

sub cleaned {
  my ($self, $field) = @_;
  my $text = $self->field($field);
  my $cleaned = convert($text);
  #make it real clean
  $cleaned = $self->_remove_escape_formats($cleaned);
  $cleaned = $self->_real_clean($cleaned);
  return $cleaned;
}

sub _remove_escape_formats {
  my ($self, $input) = @_;
  $input =~ s|\\emph\{(.*?)\}|<em>$1</em>|g;
  return $input;
}

sub _real_clean {
  my ($self, $input) = @_;
  $input =~ s/{([^{|}]*)}/$1/g;
  return $input;
}

sub pages {
  my $self = shift;
  my $pages = $self->field('pages');
  if ($pages) {
    $pages =~ s/--/-/g;
  }
  else {
    warn $self->type . ": " . $self->key  . " is missing page numbers\n";
  }
  return $pages;
}

sub pubmedlink {
  my $self = shift;
  my $pmid = $self->field('pmid');
  if ($pmid) {
    return qq|<a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=PubMed&cmd=Retrieve&list_uids=$pmid&dopt=Abstract"><span class="glyphicon glyphicon-globe"></span> abstract</a>|;
  }
  else {
    warn $self->type . ": " . $self->key  . " is missing a pmid\n";
  }
  return;
}

sub title_link {
  my $self = shift;
  my $link = undef;
  # if we have a reprint url use that
  if ($self->has('reprinturl')) {
    $link = $self->field('reprinturl');
  }
  # else look in the publications directory to see if we have a
  # reprint available an use that.
  elsif ($self->local_reprint_url) {
    $link = $self->local_reprint_url;
  }
  else {
    warn "No link for: " . $self->key . "\n";
  }
  return $link;
}

sub reprint_link {
  my $self = shift;
  my $link = undef;
  my $url  = $self->local_reprint_url;
  if ($url && $url =~ /preprint\.p(s|df)$/) {
    $link = qq(<a href="$url"><span class="glyphicon glyphicon-file"></span> preprint</a>);
  } elsif ($url && $url =~ /reprint\.p(s|df)$/) {
    $link = qq(<a href="$url"><span class="glyphicon glyphicon-file"></span> reprint</a>);
  }
  elsif ($url) {
    $link = qq(<a href="$url"><span class="glyphicon glyphicon-file"></span> reprint</a>);
  }
  return $link;
}

sub local_reprint_url {
  my ($self, $count) = @_;
  unless (exists $self->{_local_reprint_url}) {
    my $key = $self->key;
    my $root = $self->root_url;
    # open up the publications directory for this entry and look
    # for a .pdf or .ps file.
    # if we find one, create the link for it and cache it.
    foreach my $doctype (@{$self->doctypes}) {
      my $path = "./site/" . $self->pubsdir . "/$key/$key-$doctype";
      if ( -f $path ) {
        my $url = $root . $self->pubsdir . "/$key/$key-$doctype";
        $self->{_local_reprint_url} =  $url;
        last;
      }
    }
  }
  return $self->{_local_reprint_url};
}

sub links {
  my $self = shift;
  my $key = $self->key;
  my %links = ();
  my %labels = (
    "SUPPLEMENT"     =>"Supplementary material",
    "EDATA"          => "Parsable e-data",
    "SUPPLEMENT_URL" => "Supplementary web site",
    "SOFTWARE_URL"   => "Download software",
    "DATABASE_URL"   => "Database access",
    "SERVER_URL"     => "Analysis server",
  );

  # open up the NOTES file and peak in the publications directory.
  my $path = "./site/" . $self->pubsdir . "/@{[$self->key]}/00NOTES";
  if ( -f $path ) {
    open my $notes, '<', $path
      or warn "Unable to open the notes file for $path: $!\n";

    while (<$notes>) {
      next if /^\s*$/;
      if (/^\s*(\S+)\s*\{(.*)\}\s*\{(.*)\}\s*$/) {
        my $url = $3;
        my $label = $1;
        my $text = $2;

        if ($label !~ /_URL$/) {
          $url = $self->root_url . $self->pubsdir . "/$key/$url";
        }

        push @{$links{$label}}, {
          'type'  => $label,
          'label' => $labels{$label},
          'text'  => $text,
          'url'   => $url,
        };
      }
    }
  }

  return \%links;
}

1;
