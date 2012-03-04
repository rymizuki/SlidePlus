package SlidePlus::DB;
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
    q{UPDATE slide SET title = ?, content = ? WHERE rid = ? AND user_rid = ? AND deleted_fg = 0},
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


