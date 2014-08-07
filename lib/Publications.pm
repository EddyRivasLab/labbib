package Publications;

use strict;
use warnings;

use BibTeX::HTMLParser;
use IO::String;
use File::Slurp;
use Template;

sub new {
  my ($class, %args) = @_;
  my $self = {
    _labbib_dir => $ENV{HOME}."/labbib",
    _pubs_dir   => "publications",
    _url        => "http://selab.janelia.org",
    _labbib     => "lab.bib",
    _labweb     => "labweb.bib",
  };
  bless $self, $class;
  for my $k (keys %args) {
    if ($self->can($k)) {
      $self->$k($args{$k});
    }
  }
  return $self;
}

sub labbib_dir {
  my ($self, $new) = @_;
  if ($new) {
    $self->{_labbib_dir} = $new;
  }
  return $self->{_labbib_dir};
}

sub permalink {
  my ($self, $new) = @_;
  if ($new) {
    $self->{_permalink} = $new;
  }
  return $self->{_permalink};
}

sub pubs_dir {
  my ($self, $new) = @_;
  if ($new) {
    $self->{_pubs_dir} = $new;
  }
  return $self->{_pubs_dir};
}

sub url {
  my ($self, $new) = @_;
  if ($new) {
    $self->{_url} = $new;
  }
  return $self->{_url};
}

sub labbib {
  my ($self, $new) = @_;
  if ($new) {
    $self->{_labbib} = $new;
  }
  return $self->{_labbib};
}

sub labweb {
  my ($self, $new) = @_;
  if ($new) {
    $self->{_labweb} = $new;
  }
  return $self->{_labweb};
}

sub get_publications {
  my ($self, %args) = @_;

  my @entries = ();
  my %types   = ();
  my $type   = qr{.*};

  my $strings = read_file($self->labbib_dir . "/" . $self->labweb);
  my $entries = read_file($self->labbib_dir . "/" . $self->labbib);
  my $fh      = IO::String->new($strings . $entries);
  my $parser = BibTeX::HTMLParser->new($fh);

  $type = qr|^$args{type}$|i if ($args{type});

  my $count = 0;

  while (my $entry = $parser->next) {
    if ($entry->parse_ok) {
      if ($args{keyword}) {
        my $keywords = $entry->field('lab_keywords');
        next unless $keywords;
        my @keywords = split ',', $entry->field('lab_keywords');
        my $found = 0;
        for my $word (@keywords) {
          if ($word =~ /$args{keyword}/ ) {
            $found++;
            last;
          }
        }
        next unless ($found);
      }
      if ($args{index} && $entry->key !~ /$args{index}/) {
        next;
      }
      if ($entry->type =~ $type) {
        $entry->pubsdir($self->pubs_dir);
        $entry->pubsurl($self->url);
        #use DDP {class => {inherited => 'public' } }; p $entry;
        push @entries, $entry;
        $types{$entry->type}++;
        $count++;
      }
    }
    else {
      warn $entry->error;
    }
    last if (defined $args{count} && $count >= $args{count});
  }

  # can sort by fields if desired.
  @entries = sort {$b->field('year') cmp $a->field('year') } @entries;

  my $vars = {
    nodiv    => $args{nodiv},
    entries  => \@entries,
  };

  my $text = '';
  my $template = Template->new(OUTPUT => \$text);
  $template->process(\*DATA, $vars) || die $template->error();
  $text =~ s|\\emph{(.*)}|<em>$1</em>|g;
  return $text;

}



1;

__DATA__
[%- BLOCK title -%]
[%- title_link = entry.title_link -%]
[%- IF title_link %]
  <a href="[% title_link %]" id="[% entry.key %]">
[%- END -%]
[% entry.cleaned('title') %]
[%- IF title_link %]</a>.[%- END -%]
[%- END -%]
[%- BLOCK notes -%]
<div>
[%- FOREACH key IN entry.links.keys.sort -%]
  [%- IF entry.links.$key.0.label -%]
  [% entry.links.$key.0.label %] :
  [%- END -%]
  [%- FOREACH link IN entry.links.$key -%]
    [%- IF link.type == "CORRECTION" -%]
    There is a <a href="[% link.url %]">[[% link.text %]]</a> for this publication.
    [%- ELSE -%]
    <a href="[% link.url %]">[[% link.text %]]</a>
    [%- END -%]
  [%- END -%]
  <br/>
[%- END -%]
</div>
[%- END -%]

[%- year = 0000 -%]

<ul>
[%- FOREACH entry IN entries -%]
[%- IF ! nodiv -%]
[%- IF entry.year != year -%]
  [%- year = entry.year -%]
</ul>
<h2>[% year%]</h2>
<ul>
[%- END -%]
[%- END -%]

[%- IF entry.type == 'ARTICLE' -%]
<li>
[%- PROCESS title -%]
[%- FOREACH author IN entry.cleaned_author -%]
  [% author.first %] [% author.last %][% IF ! loop.last %],[% END %]
[%- END -%].
<em>[% entry.cleaned_field('journal') %]</em>,
[% IF entry.volume && entry.pages %][% entry.volume %]:[% entry.pages %],[% END %]
[% entry.year %].
[% entry.pubmedlink %]
[% entry.reprint_link -%]
[%- PROCESS notes -%]
</li>

[%- ELSIF entry.type == 'PHDTHESIS' -%]
<li>
<em>[%- PROCESS title -%]</em>
[%- FOREACH author IN entry.cleaned_author -%]
  [% author.first %] [% author.last %][% IF ! loop.last %],[% END %]
[%- END -%].
PhD Thesis:[% entry.field('school') %], [% entry.year %].
[% entry.reprint_link -%]
[%- PROCESS notes -%]
</li>

[%- ELSIF entry.type == 'BOOK' -%]
<li>
<em>[%- PROCESS title -%]</em>
[%- FOREACH author IN entry.cleaned_author -%]
  [% author.first %] [% author.last %][% IF ! loop.last %],[% END %]
[%- END -%].
[% entry.publisher %], [% entry.year %].
[% entry.reprint_link -%]
[%- PROCESS notes -%]
</li>

[%- ELSIF entry.type == 'INCOLLECTION' -%]
<li>
[%- PROCESS title -%]
In: <em>[% entry.cleaned('booktitle') %]</em>[%- IF entry.pages -%], [% entry.pages %][%- END -%].
[%- FOREACH author IN entry.cleaned_author -%]
  [% author.first %] [% author.last %][% IF ! loop.last %],[% END %]
[%- END -%].
[% entry.publisher %], [% entry.year %].
[% entry.reprint_link -%]
[%- PROCESS notes -%]
</li>

[%- ELSIF entry.type == 'INPROCEEDINGS' -%]
<li>
[%- PROCESS title -%]
In: <em>[% entry.cleaned('booktitle') %]</em>,
[% entry.pages %].
[%- FOREACH author IN entry.cleaned_author -%]
  [% author.first %] [% author.last %][% IF ! loop.last %],[% END %]
[%- END -%],
[% entry.year %].
[% entry.reprint_link -%]
[%- PROCESS notes -%]
</li>

[%- ELSIF entry.type == 'MASTERSTHESIS' -%]
<li>
<em>[%- PROCESS title -%]</em>
[%- FOREACH author IN entry.cleaned_author -%]
  [% author.first %] [% author.last %][% IF ! loop.last %],[% END %]
[%- END -%].
Masters Thesis: [%entry.school %], [% entry.year %].
[% entry.reprint_link -%]
[%- PROCESS notes -%]
</li>

[%- ELSIF entry.type == 'TECHREPORT' -%]
<li>
[%- PROCESS title -%]
[%- FOREACH author IN entry.cleaned_author -%]
  [% author.first %] [% author.last %][% IF ! loop.last %],[% END %]
[%- END -%].
[% entry.year %]
[% entry.reprint_link -%]
[%- PROCESS notes -%]
</li>

[%- ELSIF entry.type == 'UNPUBLISHED' -%]
<li>
[%- PROCESS title -%]
[%- FOREACH author IN entry.cleaned_author -%]
  [% author.first %] [% author.last %][% IF ! loop.last %],[% END %]
[%- END -%].
[% entry.note %], [% entry.year %].
[% entry.reprint_link -%]
[%- PROCESS notes -%]
</li>

[%- END -%]
[%- END -%]
</ul>
