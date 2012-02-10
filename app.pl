package Bootstrap;
use strict;
use warnings;
use 5.010_000;
use Config::Pit;
use Scope::Container;

sub run {
    my $sc = start_scope_container;

    unless (scope_container('config')) {
        my $user = Config::Pit::pit_get(dev_slide_plus => require {
            name    => 'mysql user name',
            pass    => 'mysql user pass',
        });

        scope_container(config => {
            dbi_info    => ['dbi:mysql:slide-plus', $user->{name}, $user->{pass}],
        });
    }
}

1;

package main;
use strict;
use warnings;
use 5.010_000;

use Mojolicious::Lite;
plugin 'xslate_renderer';

get '/' => sub {
    my $self  = shift;
    $self->render(
        handler     => 'tx',
        template    => 'index',
        msg         => 'hallo'
    );
} => 'index';

get '/json' => sub {
    my $self  = shift;
    $self->render(json => {msg => 'hello world!'});
};

app->start;
