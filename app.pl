package Bootstrap;
use strict;
use warnings;
use 5.010_000;
use Config::Pit;
use Scope::Container;

my $user = Config::Pit::pit_get(dev_slide_plus => require => {
    name    => 'mysql user name',
    pass    => 'mysql user pass',
});

sub run {
    my $sc = start_scope_container;

    unless (scope_container('config')) {

        scope_container(config => {
            dbi_info    => ['dbi:mysql:slide-plus', $user->{name}, $user->{pass}],
        });
    }
}

1;

package DB;
use strict;
use warnings;
use 5.010_000;
use parent qw/DBIx::Sunny::Schema/;

use Scope::Container;
use Scope::Container::DBI;
local $Scope::Container::DBI::DBI_CLASS = 'DBIx::Sunny';

=pod

=head1 CatLifeKossy::DB

DB周りのメソッド群

=head2 get_db

DBのインスタンス取得メソッド

    my $db = CatLifeKossy::DB->get_db;

=cut
sub get_db {
    my $class = shift;

    unless (my $instance = scope_container('db')) {
        my $dbh = $class->_get_dbh;
        $class->new(dbh => $dbh, readonly => 0);
    }
}

sub _get_dbh {
    my $class = shift;

    my $dbi_info = scope_container('config')->{dbi_info};
    my $dbh = Scope::Container::DBI->connect(@$dbi_info);

    return $dbh;
}

1;

package main;
use strict;
use warnings;
use 5.010_000;

use Mojolicious::Lite;
plugin 'xslate_renderer';

Bootstrap->run;


=pod

=head2 /:any_method

認証の無いページ

=cut
get '/' => sub {
    my $self  = shift;

    my $values = {msg => 'Hello!'};
    $self->render(index => %{$values});
};

get '/auth' => sub {
    my $self = shift;

    $self->render('auth');
};

get '/authorize' => sub {
    my $self = shift;

    $self->redirect_to('/');
};

get '/slide/show/:guid' => sub {
    my $self = shift;

    $self->render(text => 'show!'.$self->param('guid'));
};


=pod

=head2 /:any_method

認証が必要なページ

=cut
under '/' => sub {
    my $self = shift;

    if (!$self->session('is_login')) {
        return $self->redirect_to('/authorize');
    }
};

get '/user/register' => sub {
    my $self = shift;

    $self->render('user/register');
};

post '/user/register' => sub {
    my $self = shift;
};

get '/user/logout' => sub {
    my $self = shift;

    $self->session(expire => 1);
    $self->redirect_to('/');
};


=pod

=head2 /slide/:any_method

スライド管理系のページ

=cut
get '/slide/add' => sub {
    my $self = shift;

    $self->render_text('add!')
};

post '/slide/add' => sub {
    my $self = shift;
};

get '/slide/edit/:guid' => sub {
    my $self = shift;

    $self->render_text($self->param('guid'));
};

post '/slide/edit:guid' => sub {
    my $self = shift;
};

post '/slide/remove:guid' => sub {
    my $self = shift;
};


app->log->level('debug');
app->start;
