#!/usr/bin/perl -w

use strict;

use XML::LibXML;
use FindBin;
use Pod::Usage;
use Getopt::Long qw(GetOptions);

my(%opt, $have_vim_highlight);

if(!GetOptions(\%opt, 'help|?', 'devmode|d')) {
    pod2usage(-exitval => 1,  -verbose => 0);
}

pod2usage(-exitstatus => 0, -verbose => 2) if($opt{'help'});

chdir($FindBin::Bin) or die "chdir($FindBin::Bin): $!";

my %template = (
  index => Template::MasonLite->new_from_file('./_index.html'),
  toc   => Template::MasonLite->new_from_file('./_toc.html'),
  slide => Template::MasonLite->new_from_file('./_slide.html'),
  notes => Template::MasonLite->new_from_file('./_notes.html'),
);

my $file = 'talk.xml';

my $parser = XML::LibXML->new;
my $doc    = $parser->parse_file($file);
my $root   = $doc->getDocumentElement;

gen_title_page($root);
gen_contents_page($root);
gen_slides($root);
gen_notes($root);

exit;


sub gen_title_page {
  my($doc) = @_;

  my $data = {
    title     => $root->findvalue('/presentation/title'),
    subtitle  => $root->findvalue('/presentation/subtitle'),
    author    => $root->findvalue('/presentation/author'),
    email     => $root->findvalue('/presentation/email'),
    next      => 'slide01.html',
  };

  save_file($template{index}, 'index.html', $data);
}


sub gen_contents_page {
  my($doc) = @_;

  my @page;

  my $count = 1;
  foreach my $slide ($doc->findnodes('/presentation/slide')) {
    push @page, {
      page   => sprintf("slide%02u.html", $count++),
      title  => $slide->findvalue('./title'),
    };
    pop @page if(
      @page > 1  and  (
        not $page[-1]->{title}                          # skip blank titles
        or  $page[-1]->{title} eq $page[-2]->{title}    # and dupes
      )
    );
  }
  my $data = {
    title  => 'Contents',
    page   => \@page,
    prev   => 'index.html',
    next   => 'slide01.html',
  };
  save_file($template{toc}, 'toc.html', $data);
}


sub gen_slides {
  my($doc) = @_;

  my @page;

  my $count = 1;
  foreach my $slide ($doc->findnodes('/presentation/slide')) {
    my @content;
    foreach my $node ($slide->findnodes('./screenshot|./bullet|./code|./quote')) {
      my $type = $node->nodeName;
      if($type eq 'screenshot') {
        my $filename = $node->to_literal;
        my $img_src = "html/images/$filename";
        push @content, [ screenshot => $filename ];
      }
      elsif($type eq 'bullet') {
        push @content, [ bullets => [] ] if(!@content or $content[-1] ne 'bullets');
        push @{$content[-1][1]}, join '', map { $_->toString} $node->childNodes;
      }
      elsif($type eq 'quote') {
        push @content, [ quotes => [] ] if(!@content or $content[-1] ne 'quotes');
        push @{$content[-1][1]}, join '', map { $_->toString} $node->childNodes;
      }
      else {
        my $code = outdent($node->to_literal);
        my $language = $node->findvalue('./@syntax') || '';
        $code = syntax_highlight($code, $language) if $language;
        push @content, [ code => $code ];
      }
    }
    my $data = {
      title    => $slide->findvalue('./title'),
      content  => \@content,
      prev     => $count > 1 ? sprintf("slide%02u.html", $count-1) : 'toc.html',
      prefetch => [],
    };
#    my($commentary) = $slide->findnodes('./commentary');
#    if($commentary) {
#      $data->{commentary} = $commentary->to_literal;
#    }
    my $image_src = $slide->findvalue('./image/@src');
    $data->{image_src} = $image_src if($image_src);
    if($slide->findnodes('./following::slide')) {
      $data->{next} = sprintf("slide%02u.html", $count+1);
    }
    else {
      $data->{next} = 'index.html';
    }
    foreach my $img (
      $slide->findnodes('./following::slide[1]/screenshot'),
      $slide->findnodes('./following::slide[1]/image/@src')
    ) {
      push @{$data->{prefetch}}, $img->to_literal;
    }
    save_file($template{slide}, sprintf("slide%02u.html", $count), $data);
    $count++;
  }
}


sub gen_notes {
  my($doc) = @_;

  my @page;

  my $count = 0;
  foreach my $slide ($doc->findnodes('/presentation/slide')) {
    $count++;
    my $notes = $slide->findvalue('./notes') || '';
    my @notes = grep /\S/, map { s/^\s+//; s/\s+$//; $_} split /\n/, $notes;
    next unless @notes;
    push @page, {
      title => $slide->findvalue('./title'),
      notes => \@notes,
      image => sprintf("slide%02u.png", $count),
    };
  }
#  save_file($template{notes}, '../screendumps/index.html', 
#    { slides => \@page, title => "Speaker's Notes" }
#  );
}


sub outdent {
  local($_) = @_;

  s/\s+$//s;
  s/^\s*?\n//s;
  if(my($prefix) = (/^(\s+)/)) {
    s/^$prefix//mg;
  }
  return $_;
}


sub syntax_highlight {
  my($code, $language) = @_;

  if(!defined $have_vim_highlight) {
    eval 'require Text::VimColor';
    if($@) {
      warn "Warning: Text::VimColor is required for syntax highlighting\n";
      $have_vim_highlight = 0;
    }
    else {
      $have_vim_highlight = 1;
    }
  }

  return $code unless $have_vim_highlight;

  my $syntax = Text::VimColor->new(
    string   => $code,
    filetype => $language,
  );

  return $syntax->html;
}


sub save_file {
  my($tmpl, $file, $data) = @_;

  if($opt{devmode}) {
    my $time = time();
    $data->{next} .= '?' . $time;
    $data->{prev} .= '?' . $time;
  }
  open my $out, '>', "./html/$file" or die "open(./html/$file): $!";
  print $out $tmpl->apply(%$data);
}

package Template::MasonLite;

use strict;
use warnings;
use Carp;

our $VERSION = '0.9';

my(
    $nl, $init_sect, $perl_sect, $perl_line, $comp_def, $comp_call, 
    $expression, $literal
);

BEGIN {
    $nl         = qr{(?:[ \r]*\n)};
    $init_sect  = qr{<%init>(.*?)</%init>$nl?}s;
    $perl_sect  = qr{<%perl>(.*?)</%perl>$nl?}s;
    $perl_line  = qr{(?:(?<=\n)|^)%(.*?)(\n|\Z)}s;
    $comp_def   = qr{<%def\s+([.\w+]+)>$nl(.*?)</%def>$nl?}s;
    $comp_call  = qr{<&\s*([\w._-]+)(?:\s*,)?(.*?)&>}s;
    $expression = qr{<%\s*(.*?)%>}s;
    $literal    = qr{(.*?(\n|(?=<%|<&|\Z)))};
}

sub new           { return bless $_[0]->_parse($_[1]),      $_[0]; }
sub new_from_file { return bless $_[0]->_parse_file($_[1]), $_[0]; }

sub apply         { my $self = shift; return $self->(@_) };

sub _parse_file {
    my($class, $template) = @_;

    open my $fh, '<', $template or croak "$!: $template";
    sysread $fh, $_, -s $template;
    return $class->_parse($_);
}

sub _parse {
    my($class, $template) = @_;

    die "No template!\n" unless defined($template);
    $_ = $template;

    my(@head, @body, %comp);
    while(!/\G\Z/sgc) {
        if   (/\G$init_sect/sgc ) { push @head, $1;        }
        elsif(/\G$perl_sect/sgc ) { push @body, $1;        }
        elsif(/\G$perl_line/sgc ) { push @body, $1;        }
        elsif(/\G$comp_def/sgc  ) { $comp{$1} = $2;        }
        elsif(/\G$comp_call/sgc ) { push @body,
                                      [ 0, "\$comp{'$1'}->apply($2)" ]; 
                                  }
        elsif(/\G$expression/sgc) { push @body, [ 0, $1 ]; }
        elsif(/\G$literal/sgc   ) { push @body, [ 1, $1 ]; }
        else {/(.*)/sgc && croak "could not parse: '$1'";  }
    };
    while(my($name, $source) = each %comp) {
        $comp{$name} = $class->new($source);
    }

    unshift @head, 'my @r; my %ARGS; %ARGS = @_ unless(@_ % 2);';
    push    @body, 'return join "", @r';

    my $code = join("\n", map {
        ref($_)
        ? ( $_->[0] ? _literal($_->[1]) : _expr($_->[1]) )
        : $_;
    } @head, @body);

    $_ = '';
    my $sub = eval "sub { $code }";
    croak $@ if $@;
    return $sub;
}

sub _expr    { "push \@r, $_[0];"; }
sub _literal { $_ = shift; s/'/\\'/g; s/\\\n//s; _expr("'$_'"); }

# End of Template::MasonLite

sub h {
    $_ = shift;
    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    $_;
}

__END__


=head1 NAME

mkpres - generate HTML slide files from talk.xml

=head1 SYNOPSIS

  mkpres [options]

  Options:

   -d     enable 'dev' mode - links will be timestamped
   -?     detailed help message

=head1 DESCRIPTION

Generates a linked set of HTML slide files from the contents of F<talk.xml>.

=head1 OPTIONS

=over 4

=item B<-d>

Enables 'dev' mode.  When this mode is enabled, the 'next' and 'previous'
links between slides will be made unique through the addition of a numeric 
query-string.  This is handy for working around browser caching issues while
the presentation is under development.

You almost certainly don't want this option enabled when generating the final
version of a presentation for publication on the web.

=item B<-?>

Display this documentation.

=back

=cut

