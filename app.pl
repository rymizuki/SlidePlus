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

package DB;
use strict;
use warnings;
use 5.010_000;
use parent qw/DBIx::Sunny::Schema/;

use Scope::Container;
use Scope::Container::DBI;
our $Scope::Container::DBI::DBI_CLASS = 'DBIx::Sunny';

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

    my $dbi_info = $class->_get_dbi_info;
    my $dbh = Scope::Container::DBI->connect(@$dbi_info);

    return $dbh;
}

sub _get_dbi_info {scope_container('config')->{dbi_info}}


1;

package main;
use strict;
use warnings;
use 5.010_000;

use Mojolicious::Lite;
plugin 'xslate_renderer';

Bootstrap->run;

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
