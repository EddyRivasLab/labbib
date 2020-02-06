package Publications;

use strict;
use warnings;

use BibTeX::HTMLParser;
use IO::String;
use File::Slurp;
use Template;
use Search::QueryParser;

sub new {
  my ($class, %args) = @_;
  my $self = {
    _labbib_dir => $ENV{HOME}."/labbib",
    _pubs_dir   => "publications",
    _url        => "http://eddylab.org/",
    _bibfile    => "lab.bib",
    _labweb     => "labweb.bib",
    _template   => "default",
  };
  bless $self, $class;
  for my $k (keys %args) {
    if ($self->can($k)) {
      $self->$k($args{$k});
    }
  }
  return $self;
}

sub template {
  my ($self, $new) = @_;
  if ($new) {
    $self->{_template} = $new;
  }
  return $self->{_template};
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

sub bibfile {
  my ($self, $new) = @_;
  if ($new) {
    $self->{_bibfile} = $new;
  }
  return $self->{_bibfile};
}

sub labweb {
  my ($self, $new) = @_;
  if ($new) {
    $self->{_labweb} = $new;
  }
  return $self->{_labweb};
}

sub keyword_check {
  my ($self, $query, $keywords) = @_;
  my @result = ();
  # The query parsing code outputs the symbols +,- and ''. We need to
  # convert these into keywords that perl understands in conditional
  # statements, so we use this map to do that.
  my %prefix_map = (
    '+' => 'and ',
    ''  => 'or ',
    '-' => 'and !',
  );

  # The count is used to determine if we are at the beginning of a statement
  # or somewhere else. We use the count later to decide if we need to add
  # the prefix to the string. Adding a prefix to the beginning of a statement
  # results in a string like this "+keyword +keyword" which, after substitution
  # through the prefix map, becomes "and keyword and keyword", which breaks
  # in the eval(). Removing it fixes the problem and doesn't hurt the results in
  # my test cases.
  my $count = 0;
  foreach my $prefix ('+', '', '-') {
    next if not $query->{$prefix};
    foreach (@{$query->{$prefix}}) {
      $count++;
      my $string = $self->build_sub_keyword($_, $keywords);

      if ($count > 1) {
        push @result, $prefix_map{$prefix} . $string;
      }
      else {
        push @result, $string;
      }
    }
  }

  my $result_string = join ' ', @result;
  return $result_string;
}

sub build_sub_keyword {
  my ($self, $subquery, $keywords) = @_;
  return "(" . $self->keyword_check($subquery->{value}, $keywords) . ")" if $subquery->{op} eq '()';

  # Simply look through the list of keywords and if we find a match
  # return true. This converts our search string from something like
  # "hmmer AND infernal" to "1 and 0" which is perfectly acceptable in
  # a conditional check. It also means that we can't inject nasty
  # things into the eval statement later on.
  my $result = 0;
  for my $keyword (@$keywords) {
    if ($keyword eq $subquery->{value}) {
      $result = 1;
      last;
    }
  }
  return $result;
}

sub get_publications {
  my ($self, %args) = @_;

  my @entries = ();
  my %types   = ();
  my $type   = qr{.*};

  my $strings = read_file($self->labbib_dir . "/" . $self->labweb);
  my $entries = read_file($self->labbib_dir . "/" . $self->bibfile);
  my $fh      = IO::String->new($strings . $entries);
  my $parser = BibTeX::HTMLParser->new($fh);

  $type = qr|^$args{type}$|i if ($args{type});

  my $count = 0;

  my $query = undef;
  my $prefix = q{};

  # this block of code parses a boolean search string and breaks it down
  # into a data structure ($query) that can be used to generate a much
  # simpler string that gets created and checked with each entry.
  if ($args{keyword}) {
    my $qp = Search::QueryParser->new();
    if ($args{keyword} =~ s/^\s*NOT//) {
      $prefix = '!';
    }
    $query = $qp->parse($args{keyword}) or die "Error in provided keyword string: " . $qp->err;
  }

  while (my $entry = $parser->next) {
    if ($entry->parse_ok) {
      if ($args{keyword}) {
        my $keywords = $entry->field('lab_keywords') || '';
        my @keywords = split ',', $keywords;
        # takes the query data structure we generated earlier and recurses
        # down that to generate a simple boolean statement that gets evaluated
        # in an unless statement below.
        my $args = $self->keyword_check($query, \@keywords);
        $args = "$prefix($args)";
        next unless (eval $args);
      }
      if ($args{index} && $entry->key !~ /$args{index}/) {
        next;
      }
      if ($entry->type =~ $type) {
        $entry->pubsdir($self->pubs_dir);
        $entry->pubsurl($self->url);
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

  if ($self->template eq 'default') {
    $template->process(\*DATA, $vars) || die $template->error();
  }
  else {
    #slurp in the template file provided
    $template->process('selab.tt', $vars) || die $template->error();
  }
  $text =~ s|\\emph\{(.*)\}|<em>$1</em>|g;
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
[%- IF title_link %]</a>. [%- ELSE -%]. [%- END -%]
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
[%- PROCESS title -%] <br />
[%- FOREACH author IN entry.cleaned_author -%]
  [% author.first %] [% author.last %][% IF ! loop.last %],[% END %]
[%- END -%]. <br />
<em>[% entry.cleaned_field('journal') %]</em>,
[% IF entry.volume && entry.pages %][% entry.volume %]:[% entry.pages %],[% END %]
[% entry.year %]. <br />
[%- PROCESS notes -%]
[% entry.pubmedlink %]
[% entry.reprint_link -%]
</li>

[%- ELSIF entry.type == 'PHDTHESIS' -%]
<li>
<em>[%- PROCESS title -%]</em> <br />
[%- FOREACH author IN entry.cleaned_author -%]
  [% author.first %] [% author.last %][% IF ! loop.last %],[% END %]
[%- END -%]. <br />
PhD Thesis, [% entry.field('school') %], [% entry.year %]. <br />
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
[%- PROCESS title -%] <br />
[%- FOREACH author IN entry.cleaned_author -%]
  [% author.first %] [% author.last %][% IF ! loop.last %],[% END %]
[%- END -%],
[% entry.year %]. <br />
[% entry.reprint_link -%]
[%- PROCESS notes -%]
</li>

[%- ELSIF entry.type == 'UNPUBLISHED' -%]
<li>
[%- PROCESS title -%] <br />
[%- FOREACH author IN entry.cleaned_author -%]
  [% author.first %] [% author.last %][% IF ! loop.last %],[% END %]
[%- END -%]. <br />
[% entry.note %], [% entry.year %]. <br />
[%- PROCESS notes -%]
[% entry.reprint_link -%]
</li>

[%- END -%]
[%- END -%]
</ul>
