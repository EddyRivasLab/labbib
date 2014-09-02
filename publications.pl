#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use Publications;
use Getopt::Long;

my $opts = {};
GetOptions(
  $opts,
  'help',
  'nodividers',
  'labbib_dir:s',
  'pubs_dir:s',
  'count:i',
  'type:s',
  'keyword:s',
  'index:s',
  'url:s',
) or usage();

if (exists $opts->{help}) {
  usage();
}

if ($ARGV[0]) {
  $opts->{bibfile} = $ARGV[0];
}

my $pubs = Publications->new(%$opts);

my $html = $pubs->get_publications(
  count   => $opts->{count},
  type    => $opts->{type},
  nodiv   => $opts->{nodividers},
  keyword => $opts->{keyword},
  index   => $opts->{index},
);

binmode STDOUT, ":encoding(UTF-8)";

print $html;

sub usage {
  print qq|($0 [options] <bibfiles>

  Creates an HTML lists of publications based on the data in your
  local lab.bib and labweb.bib files.

  Specify the bib files on the command line if you are not using
  the default lab.bib and labweb.bib files to store our bibtex data.

  options:
    -h, --help                     : Print this message and exit
    -l <dir>, --labbib_dir=<dir>   : The directory that contains all the bibtex files.
                                     [default: $ENV{HOME}/labbib ]
    -p <dir>, --pubs_dir=<dir>     : Path to the publications directory that contains pdfs
                                     and supplemental material.
                                     [default: $ENV{HOME}/selab/publications ]
    -k <string>, --keyword=<string>: Limit the output to entries that match the keyword input.
                                     This is entered as a boolean search string. examples:
                                     'hmmer AND lab'
                                     '(lab NOT hmmer) AND recent'
                                     'NOT lab'
    -t <type>, --type=<type>       : Limit the output to the selected entry type. eg [ARTICLE]
    -n, --nodividers               : Turn off the dividers between years
    -u <url>, --url=<url>          : The base url for the site. eg [http://selab.janelia.org]
    -i <index>, --index=<index>    : Limit results to an article key. eg [Eddy01].
|;

  exit 1;
}
