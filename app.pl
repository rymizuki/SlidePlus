package main;
use strict;
use warnings;
use 5.010_000;
use lib qw/lib/;

use Mojolicious::Lite;
use Mojo::JSON;

use DateTimeX::Factory;
use HTML::FillInForm::Lite qw/fillinform/;
use Log::Minimal;
use Scope::Container;
use Text::Xslate qw/html_builder/;
use Validator::Custom;


use SlidePlus::Auth;
use SlidePlus::Bootstrap;
use SlidePlus::DB;
use SlidePlus::Util::Template;

=pod

=head2

Mojolicious::LiteのPluginセットアップ

=cut
plugin 'xslate_renderer' => {
    template_options => {
        function    => {
            fillinform          => html_builder(\&fillinform),
            format_from_xatena  => \&format_from_xatena,
        },
    },
};

=pod

=head2 /slide/show/:rid/:page

スライドページ

=cut
get '/slide/show/:rid/:page' => {rid => undef, page => 0}, sub {
    my $self = shift;

    my $row = SlidePlus::DB->get_db->get({rid => $self->param('rid')});
    $self->render('slide/show', show => $row);
};

my $clients = {};
websocket '/websocket/:rid' => {rid => undef}, sub {
    my $self = shift;

    $self->app->log->debug('socket open');

    my $id  = sprintf "%s", $self->tx;
    my $rid = $self->param('rid');
    $clients->{$rid}{$id} = $self->tx;

    $self->on(message => sub {
        my ($self, $msg) = @_;

        $self->app->log->debug($msg);
        
        #my $json = Mojo::JSON->new->encode($msg);
        for (keys %{$clients->{$rid}}) {
            $clients->{$rid}{$_}->send_message($msg);
        }
    });

    $self->on(finish => sub {
        my $self = shift;
        $self->app->log->debug('WebSocket closed');
    });
};


=pod

=head2 /:any_method

認証の無いページ

=cut
get '/' => sub {
    my $self  = shift;

    $self->render('index');
};

get '/authorize' => sub {
    my $self = shift;

    my $conf = scope_container('config')->{oauth};
    my $auth = SlidePlus::Auth->new($conf);

    if ($self->session('is_login')) {
        return $self->redirect_to('/slide/list');
    }

    if ($self->param('verify')) {
        my $callback = {
            on_finished => sub {
                my $result = shift;

                my $user = SlidePlus::DB->get_db->login({id_str  => $result->{id_str}});

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

    my $db = SlidePlus::DB->get_db;
    $db->register(\%data);

    my $user = $db->login({id_str => $data{id_str}}); 
    unless ($user) {
        die "not found user";
    }

    $self->session(is_login => 1);
    $self->session(user_rid => $user->{rid});

    return $self->redirect_to('/slide/list');
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

    my $is_pjax = $self->param('_pjax') ? 1 : 0;
    $self->app->log->debug('this request is pjax') if $is_pjax;

    $self->stash->{is_pjax} = $is_pjax;

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

get '/slide/controller/:rid' => {rid => undef}, sub {
    my $self = shift;

    my $row = SlidePlus::DB->get_db->get({rid => $self->param('rid')});
    $self->render('slide/controller', show => $row);
};

get '/slide/list/:page' => {page => 1} => sub {
    my $self = shift;

    my ($rows, $pager) = SlidePlus::DB->get_db->list_with_pager($self->session('user_rid'), {
        limit   => 10,
        page    => $self->param('page'),
    });

    my %values = (rows => $rows, pager => $pager);
    $self->render('slide/list', %values);
};

get '/slide/add' => sub {
    my $self = shift;

    $self->render('slide/add');
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
        
        my $db = SlidePlus::DB->get_db;
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

    my $slide = SlidePlus::DB->get_db->get({rid => $self->param('rid')});

    $self->render('slide/add', fill => $slide);
};

post '/slide/edit/:rid' => sub {
    my $self = shift;

    state $rule = [
        rid     => {message => 'Fault post'}    => [qw/not_blank/],
        title   => {message => 'Input title'}   => [qw/not_blank/],
        content => {message => 'Input content'} => [qw/not_blank/],
    ];

    my $params = $self->req->body_params->to_hash;
    $params->{rid} = $self->param('rid');

    my $validator = Validator::Custom->new;
    my $v_result = $validator->validate($params, $rule);

    if (delete $params->{register}) {
        # 更新処理
        unless($v_result->is_ok) {
            return $self->render_json($v_result->to_hash)
        }

        my $db = SlidePlus::DB->get_db;
        $db->edit({%$params, user_rid => $self->session('user_rid')});

        return $self->render_json({is_success => 1});
    } else {
        # 確認画面
        unless ($v_result->is_ok) {
            return $self->render('slide/add', fill => $params, result => $v_result->to_hash);
        }

        $self->render('slide/confirm', fill => $params);
    }
};

post '/slide/remove:rid' => sub {
    my $self = shift;

    SlidePlus::DB->get_db->remove({rid => $self->param('rid'), user_rid => $self->session('user_rid')});

    return $self->render_json({is_success => 1});
};


=pod

=head2

環境設定

=cut
local $ENV{LM_DEBUG} = 1;
local $ENV{MOJO_WEBSOCKET_DEBUG} = 1;

app->log->level('debug');

SlidePlus::Bootstrap->run;

app->start;
