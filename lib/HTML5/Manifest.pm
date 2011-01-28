package HTML5::Manifest;
use strict;
use warnings;
our $VERSION = '0.01';

use Digest::MD5 'md5_base64';
use File::Spec;
use IO::Dir;

sub new {
    my($class, %args) = @_;
    bless {
        %args
    }, $class;
}

sub _recurse {
    my($self, $path, $cb) = @_;

    my $dir = IO::Dir->new($path) or die "Can't open directory $path: $!";
    while (defined(my $entry = $dir->read)) {
        next if $entry eq File::Spec->updir || $entry eq File::Spec->curdir;
        my $new_path = File::Spec->catfile($path, $entry);
        my $is_dir = -d $new_path;
        $entry = "$entry/" if $is_dir;
        my $is_pass = $cb->($new_path, $entry, $is_dir);
        next unless $is_pass;
        if ($is_dir) {
            $self->_recurse($new_path, $cb);
        }
    }
}

sub generate {
    my $self = shift;

    my $manifest = "CACHE MANIFEST\n\n";
    if ($self->{network} && ref $self->{network} eq 'ARRAY') {
        $manifest .= "NETWORK:\n";
        for my $path (@{ $self->{network} }) {
            $manifest .= "$path\n";
        }
        $manifest .= "\n";
    }

    my $htdocs = $self->{htdocs};
    $manifest .= "CACHE:\n";
    $self->_recurse($htdocs, sub {
        my($fullpath, $filename, $is_dir) = @_;
        my $manifest_path = $fullpath;
        $manifest_path =~ s/^$htdocs//;

        for my $qr (@{ $self->{skip} || [] }) {
            return 0 if $filename =~ $qr;
        }
        return 1 if $is_dir;

        $manifest .= $manifest_path;
        if ($self->{use_digest}) {
            $manifest .= ' # ' . md5_base64(do {
                open my $fh, '<', $fullpath or die "Can't open file $fullpath: $!";
                local $/;
                <$fh>;
            });
        }
        $manifest .= "\n";
        return 1;
    });

    return $manifest;
}

1;
__END__

=head1 NAME

HTML5::Manifest - HTML5 application cache manifest file generator

=head1 SYNOPSIS

  use HTML5::Manifest;

  my $manifest = HTML5::Manifest->new(
      use_digest => 1,
      htdocs     => './htdocs/',
      skip       => [
          qr{^temporary/},
          qr{\.svn/},
          qr{\.swp$},
          qr{\.txt$},
          qr{\.html$},
          qr{\.cgi$},
      ],
      network => [
          '/api',
          '/foo/bar.cgi',
      ],
  );

  # show html5.manifest content
  say $manifest->generate;

=head1 DESCRIPTION

HTML5::Manifest is generate manifest contents of application cache in HTML5 Web application API.

=head1 AUTHOR

Kazuhiro Osawa E<lt>yappo {at} shibuya {dot} plE<gt>

=head1 SEE ALSO

L<http://www.w3.org/TR/html5/offline.html>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
