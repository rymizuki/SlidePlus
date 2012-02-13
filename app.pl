package Bootstrap;
use strict;
use warnings;
use 5.010_000;
use Config::Pit qw/pit_get/;
use DBIx::QueryLog;
use Scope::Container;

my $user = pit_get(dev_slide_plus => require => {
    name    => 'mysql user name',
    pass    => 'mysql user pass',
});
my $oauth = pit_get(slide_plus_oauth => require => {
    key   => 'twitter consumer key here',
    secret=> 'twitter consumer secret here',
});

sub run {
    our $sc = start_scope_container;

    #DBIx::QueryLog->enable;
    unless (scope_container('config')) {

        scope_container(config => {
            dbi_info    => ['dbi:mysql:slide_plus', $user->{name}, $user->{pass}],
            oauth       => {
                consumer_key    => $oauth->{key},
                consumer_secret => $oauth->{secret},
            },
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
$Scope::Container::DBI::DBI_CLASS = 'DBIx::Sunny';

use Data::Page;
use Data::Validator;
use DateTimeX::Factory;
use String::Random;

=pod

=head1 NAME CatLifeKossy::DB

DB周りのメソッド群

=cut


=pod

=head2 login

OAuthの情報を受け取り、ユーザ情報を取得する

    my $user = DB->get_db->login({id_str => $result->{id_str}});

=cut

__PACKAGE__->select_row(login => (
        id_str => {isa => 'Int'},
    ),
    q{SELECT * FROM user WHERE id_str = ? AND deleted_fg = 0 LIMIT 1},
);

=pod

=head2 register

ユーザデータを登録する

    DB->get_db->register($register_data);

=cut
__PACKAGE__->query(register => (
        rid                 => {isa => 'Str', default => sub {String::Random->new->randregex('[a-zA-Z0-9]{20}')}},
        id_str              => {isa => 'Int'},
        screen_name         => {isa => 'Str'},
        name                => {isa => 'Str'},
        description         => {isa => 'Str'},
        profile_image_url   => {isa => 'Str', default => '-'},
        url                 => {isa => 'Str', default => '-'},
        created_at          => {isa => 'DateTime', default => sub{DateTimeX::Factory->now->strftime('%F %T')}},
    ),
    q{
        INSERT INTO user
            (rid, id_str, name_en, name, profile_img, url, description, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    },
);

=pod

=head2 get

スライドを取得する

    my $slide = DB->get_db->get({rid => $rid});

=cut
__PACKAGE__->select_row(get => (
        rid => {isa => 'Str'},
    ),
    q{SELECT * FROM slide WHERE rid = ? AND deleted_fg = 0},
);

__PACKAGE__->select_row(get_by_id => (
        id => {isa => 'Int'},
    ),
    q{SELECT * FROM slide WHERE id = ? AND deleted_fg = 0},
);

=pod

=head2 add

スライドを登録する

    DB->get_db->add(\%data);

=cut
__PACKAGE__->query(add => (
        rid         => {isa => 'Str', default => sub {String::Random->new->randregex('[a-zA-Z0-9]{20}')}},
        user_rid    => {isa => 'Str'},
        title       => {isa => 'Str'},
        content     => {isa => 'Str'},
        created_at  => {isa => 'DateTime', default => sub{DateTimeX::Factory->now->strftime('%F %T')}},
    ),
    q{INSERT INTO slide (rid, user_rid, title, content, created_at) VALUES(?, ?, ?, ?, ?)}
);

=pod

=head2 edit

スライドを更新する

    DB->get_db->edit(\%data);
=cut
__PACKAGE__->query(edit => (
        title   => {isa => 'Str'},
        content => {isa => 'Str'},
        rid     => {isa => 'Str'},
        user_rid=> {isa => 'Str'},
    ),
    q{UPDATE slide SET (title = ?, content = ?) WHERE rid = ? AND user_rid = ? AND deleted_fg = 0},
);

=pod

=head2 remove 

スライドを削除する

    DB->get_db->remove({rid => $rid, user_rid => $user_rid});
=cut
__PACKAGE__->query(remove => (
        user_rid=> {isa => 'Str'},
        rid     => {isa => 'Str'},
    ),
    q{UPDATE slide SET (deleted_fg = 1) WHERE rid = ? AND user_rid = ? AND deleted_fg = 0},
);

=pod

=head2 list

user_ridからスライドリストを取得する

    my $list = DB->get_db->list({user_rid => $user_rid, limit => 10, offset => 0});

=cut
__PACKAGE__->select_all(list => (
        user_rid    => {isa => 'Str'},
        offset      => {isa => 'Int', default =>  0},
        limit       => {isa => 'Int', default => 10},
    ),
    q{SELECT SQL_CALC_FOUND_ROWS * FROM slide WHERE user_rid = ? AND deleted_fg = 0 ORDER BY id DESC LIMIT ?, ?},
);

=pod

=head2 found_rows

SQL_CALC_FOUND_ROWSで発行したクエリの件数を取得

    my $db = DB->get_db;
    my $list  = $db->list({user_rid => $user_rid});
    my $count = $db->found_rows();
=cut
__PACKAGE__->select_one(found_rows => q{SELECT FOUND_ROWS()});

=pod

=head2 list_with_pager

pagerとrowsのArrayを返すメソッド

    my ($rows, $pager) = DB->get_db->list_with_pager($user_rid, {limit => 10, page => $page});

=cut
sub list_with_pager {
    state $v = Data::Validator->new(
        user_rid    => {isa => 'Str'},
        limit       => {isa => 'Int', default => 10},
        page        => {isa => 'Int', default =>  1},
    )->with(qw/Method Sequenced/);
    my ($class, $args) = $v->validate(@_);

    my $offset = ($args->{page} - 1) * $args->{limit};

    my $list = $class->list({
        user_rid    => $args->{user_rid},
        limit       => $args->{limit},
        offset      => $offset,
    });
    my $found_rows = $class->found_rows;

    my $pager = Data::Page->new(
        total_entries       => $found_rows,
        entries_per_page    => $args->{limit},
        current_page        => $args->{page},
    );

    return ($list, $pager);
}

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

package OAuth;
use strict;
use warnings;
use 5.010_000;

use JSON;
use LWP::UserAgent;
use OAuth::Lite::Consumer;

use Mouse;

has consumer_key => (
    is => 'ro', isa => 'Str', required => 1,
);
has consumer_secret => (
    is => 'ro', isa => 'Str', required => 1,
);

__PACKAGE__->meta->make_immutable;

no Mouse;

sub _oauth {
    my $class = shift;
    my $oauth = OAuth::Lite::Consumer->new(
        site                => "http://twitter.com/",
        request_token_path  => "https://twitter.com/oauth/request_token",
        access_token_path   => "https://twitter.com/oauth/access_token",
        authorize_path      => "https://twitter.com/oauth/authorize",
        consumer_key        => $class->consumer_key,
        consumer_secret     => $class->consumer_secret,
    );
}

sub auth_url {
    my ($class, $c, $callback_url) = @_;

    my $oauth = $class->_oauth;
    my $request_token = $oauth->get_request_token(callback_url => $callback_url);
    my $redirect_url = $oauth->url_to_authorize(token => $request_token);

    $c->session(auth_twitter => [$request_token, ]);

    return $redirect_url;
}

sub callback {
    my ($class, $c, $callback) = @_;

    my $cookie = $c->session('auth_twitter')
        or return $callback->{on_error}->('session error');

    my $oauth = $class->_oauth;
    my $access_token = $oauth->get_access_token(
        token       => $c->param('oauth_token'),
        verifier    => $c->param('oauth_verifier'),
    );

    my $request = $oauth->gen_oauth_request(
        method  => 'GET',
        url     => q{http://api.twitter.com/1/account/verify_credentials.json},
        token   => $access_token,
    );

    my $response = LWP::UserAgent->new->request($request);

    unless ($response->is_success) {
        if ($response->status == 400 or $response->status == 401) {
            my $auth_header = $response->header('WWW-Authenticate');
            if ($auth_header and $auth_header =~ /^OAuth/) {
                return $callback->{on_error}->("access token may be expired");
            }
        }

        return $callback->{on_error}->("auth error");
    }

    my $result = decode_json($response->content);

    return $callback->{on_finished}->($result);
}

1;

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

package main;
use strict;
use warnings;
use 5.010_000;

use HTML::FillInForm::Lite qw/fillinform/;
use Log::Minimal;
use Scope::Container;
use Text::Xslate qw/html_builder/;
use Validator::Custom;

use Mojolicious::Lite;

my $home = app->home;

my %template_options = (
    function    => {
        fillinform => html_builder(\&fillinform),
        format_from_xatena  => \&SlidePlus::Util::Template::format_from_xatena,
    },
    cache_dir   => $home->rel_dir('tmp'),
);
plugin 'xslate_renderer' => {
    template_options => \%template_options,
};

my $tx = Text::Xslate->new({
    path => $home->rel_dir('templates'),
    %template_options,
});


=pod

=head2 /:any_method

認証の無いページ

=cut
use DateTimeX::Factory;
get '/' => sub {
    my $self  = shift;

    if ($self->param('_pjax')) {
        my $string = $tx->render('index.html.tx');
        $self->render_text($string);
    } else {
        $self->render('index');
    }
};

get '/authorize' => sub {
    my $self = shift;

    my $conf = scope_container('config')->{oauth};
    my $auth = OAuth->new($conf);

    if ($self->session('is_login')) {
        return $self->redirect_to('/slide/list');
    }

    if ($self->param('verify')) {
        my $callback = {
            on_finished => sub {
                my $result = shift;

                my $user = DB->get_db->login({id_str  => $result->{id_str}});

                if ($user) {
                    $self->session(is_login => 1);
                    $self->session(user_rid => $user->{rid});
                    my $return_to = $self->session('return_to') || '/slide/list';
                    $self->session(return_to => undef);
                    return $self->redirect_to($return_to);
                } else {
                    $self->session(register_data => $result);
                    return $self->redirect_to('/user/register');
                }
            },
            on_error => sub {
                my ($class, $c, $error) = @_;
            },
        };
        return $auth->callback($self => $callback);
    } else {
        my $base = $self->req->url->base;
        my $callback_url = sprintf('http://%s/authorize?verify=1', $base->host);
        my $auth_url = $auth->auth_url($self, $callback_url);
        return $self->redirect_to($auth_url);
    }
};


get '/user/register' => sub {
    my $self = shift;

    $self->render('user/register');
};

post '/user/register' => sub {
    my $self = shift;

    my $register_data = $self->session('register_data');
    my %data;
    for (qw/id_str screen_name name description url profile_image_url/) {
        $data{$_} = $register_data->{$_} || '';
    }

    my $db = DB->get_db;
    $db->register(\%data);

    my $user = $db->login({id_str => $data{id_str}}); 
    unless ($user) {
        die "not found user";
    }

    $self->session(is_login => 1);
    $self->session(user_rid => $user->{rid});

    return $self->redirect_to('/slide/list');
};


get '/slide/show/:rid/:page' => {rid => undef, page => 0}, sub {
    my $self = shift;

    my $row = DB->get_db->get({rid => $self->param('rid')});
    $self->render('slide/show', show => $row);
};


=pod

=head2 /:any_method

認証が必要なページ

=cut
under sub {
    my $self = shift;

    if (!$self->session('is_login')) {
        $self->session(return_to => $self->req->url->path);
        $self->redirect_to('/authorize');
        return;
    }

    return 1;
};

get '/user/logout' => sub {
    my $self = shift;

    $self->session(expires => 1);
    $self->redirect_to('/');
};


=pod

=head2 /slide/:any_method

スライド管理系のページ

=cut
get '/slide/list/:page' => {page => 1} => sub {
    my $self = shift;

    my ($rows, $pager) = DB->get_db->list_with_pager($self->session('user_rid'), {
        limit   => 10,
        page    => $self->param('page'),
    });

    my %values = (rows => $rows, pager => $pager);

    if ($self->param('_pjax')) {
        my $string = $tx->render('slide/list-pjax.html.tx', \%values);
        $self->render_text($string);
    } else {
        $self->render('slide/list', %values);
    }
};

get '/slide/add' => sub {
    my $self = shift;

    if ($self->param('_pjax')) {
        my $string = $tx->render('slide/add-pjax.html.tx');
        $self->render_text($string);
    } else {
        $self->render('slide/add');
    }
};

post '/slide/add' => sub {
    my $self = shift;

    state $rule = [
        title   => {message => 'Must be input'} => [qw/not_blank/],
        content => {message => 'Must be input'} => [qw/not_blank/],
    ];

    my $params = $self->req->body_params->to_hash;
    use Data::Dumper;

    my $validator = Validator::Custom->new;
    my $v_result = $validator->validate($params, $rule);

    if (delete $params->{register}) {
        # 登録処理
        unless ($v_result->is_ok) {
            return $self->render_json($v_result->to_hash);
        }
        
        my $db = DB->get_db;
        $db->add({%$params, user_rid => $self->session('user_rid')});

        return $self->render_json({is_success => 1});
    } else {
        # 確認画面の出力
        unless ($v_result->is_ok) {
            return $self->render('slide/add', fill => $params, result => $v_result->to_hash);
        }

        $self->render('slide/confirm', fill => $params);
    }
};

get '/slide/edit/:rid' => sub {
    my $self = shift;

    my $slide = DB->get_db->get({rid => $self->param('rid')});

    $self->render('slide/edit', slide => $slide);
};

post '/slide/edit' => sub {
    my $self = shift;

    state $rule = [
        rid     => {message => 'Fault post'}    => [qw/not_blank/],
        title   => {message => 'Input title'}   => [qw/not_blank/],
        content => {message => 'Input content'} => [qw/not_blank/],
    ];

    my $params = $self->req->body_params->to_hash;

    my $validator = Validator::Custom->new;
    my $v_result = $validator->validate($params, $rule);

    if ($self->req->param('register')) {
        # 更新処理
        my $result = $v_result->to_hash;
        unless($v_result->is_ok) {
            return $self->render_json($result)
        }

        my $db = DB->get_db;

        $db->edit({%$result, user_rid => $self->session('user_rid')});

        my $slide = $db->get({rid => $result->{rid}});
        return $self=>redner_json({is_success => 1, rid => $slide->{rid}});
    } else {
        # 確認画面
        my $result = $v_result->to_hash;
        unless ($v_result->is_ok) {
            return $self->render('slide/edit', fill => $params, result => $result->to_hash);
        }

        $self->render('slide/confirm' => $result);
    }
};

post '/slide/remove:rid' => sub {
    my $self = shift;

    DB->get_db->remove({rid => $self->param('rid'), user_rid => $self->session('user_rid')});

    return $self->render_json({is_success => 1});
};

local $ENV{LM_DEBUG} = 1;
Bootstrap->run;

app->log->debug(app->home);

app->log->level('debug');
app->start;
