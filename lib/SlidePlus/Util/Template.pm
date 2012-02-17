package SlidePlus::Util::Template;
use strict;
use warnings;
use 5.010_000;

use Data::Validator;
use Encode;
use Text::Xatena;

use Exporter::Lite;
our @EXPORT = qw/
    format_from_xatena
/;

=pod 

=head2 format_from_xatena

はてな記法の文字列をHTMLにパースする。

    :format_from_xatena($string) | raw 

=cut
sub format_from_xatena {
    state $v = Data::Validator->new(
        string => {isa => 'Str'},
    )->with(qw/Sequenced/);
    my $args = $v->validate(@_);

    my $xatena = Text::Xatena->new(
        templates => {
            Section => q[
                ? if ($level == 1) {
                <section class="level-1">
                    <h3>{{= $title }}</h3>
                    {{= $content }}
                </section>
                ? } else {
                <article class="level-{{= $level }}">
                    <h4>{{= $title }}</h4>
                    {{= $content }}
                </article>
                ? }
            ],
            Blockquote => q[
                <figure>
                ? if ($cite) {
                    <blockquote cite="{{= $cite }}">
                        {{= $content }}
                    </blockquote>
                    <figcaption>
                        <cite><a href="{{= $cite }}">{{= $cite }}</a></cite>
                    </figcaption>
                ? } else {
                    <blockquote>
                        {{= $content }}
                    </blockquote>
                ? }
                </figure>
            ],
        },
    );

    my $html = $xatena->format($args->{string});

    return Encode::decode_utf8($html);
}

1;


