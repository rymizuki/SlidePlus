package SlidePlus::Auth;
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


