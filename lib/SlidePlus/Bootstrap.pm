package SlidePlus::Bootstrap;
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


