package main;
use strict;
use warnings;
use 5.010_000;
use lib qw/lib/;

use DateTimeX::Factory;
use HTML::FillInForm::Lite qw/fillinform/;
use Log::Minimal;
use Scope::Container;
use Text::Xslate qw/html_builder/;
use Validator::Custom;

use Mojolicious::Lite;

use SlidePlus::Auth;
use SlidePlus::Bootstrap;
use SlidePlus::DB;
use SlidePlus::Util::Template;

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


get '/slide/show/:rid/:page' => {rid => undef, page => 0}, sub {
    my $self = shift;

    my $row = SlidePlus::DB->get_db->get({rid => $self->param('rid')});
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

    my ($rows, $pager) = SlidePlus::DB->get_db->list_with_pager($self->session('user_rid'), {
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

        my $db = SlidePlus::DB->get_db;

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

    SlidePlus::DB->get_db->remove({rid => $self->param('rid'), user_rid => $self->session('user_rid')});

    return $self->render_json({is_success => 1});
};

local $ENV{LM_DEBUG} = 1;
SlidePlus::Bootstrap->run;

app->log->debug(app->home);

app->log->level('debug');
app->start;
