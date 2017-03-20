package API::Google;

use Data::Dumper;

# ABSTRACT: Perl library for easy access to Google services via their API

=head1 SYNOPSIS

    use API::Google;
    my $gapi = API::Google->new({ tokensfile => 'config.json' });
    
    $gapi->refresh_access_token_silent('someuser@gmail.com');
    
    $gapi->api_query({ 
      method => 'post', 
      route => 'https://www.googleapis.com/calendar/v3/calendars/'.$calendar_id.'/events',
      user => 'someuser@gmail.com'
    }, $json_payload_if_post);


=head1 CONFIGURATION

config.json must be structured like:

  { "gapi":
    {
      "client_id": "001122334455-abcdefghijklmnopqrstuvwxyz012345.apps.googleusercontent.com",
      "client_secret": "1ayL76NlEKjj85eZOipFZkyM",
      "tokens": {
          "email_1@gmail.com": {
              "refresh_token": "1/cI5jWSVnsUyCbasCQpDmz8uhQyfnWWphxvb1ST3oTHE",
              "access_token": "ya29.Ci-KA8aJYEAyZoxkMsYbbU9H_zj2t9-7u1aKUtrOtak3pDhJvCEPIdkW-xg2lRQdrA"
          },
          "email_2@gmail.com": {
              "access_token": "ya29.Ci-KAzT9JpaPriZ-ugON4FnANBXZexTZOz-E6U4M-hjplbIcMYpTbo0AmGV__tV5FA",
              "refresh_token": "1/_37lsRFSRaUJkAAAuJIRXRUueft5eLWaIsJ0lkJmEMU"
          }
      }
    }
  }
	
=cut

use strict;
use warnings;
use Mojo::UserAgent;
use Config::JSON;
use Data::Dumper;


sub new {
  my ($class, $params) = @_;
  my $h = {};
  if ($params->{tokensfile}) {
  	$h->{tokensfile} = Config::JSON->new($params->{tokensfile});
  } else {
  	die 'no json file specified!';
  }
  $h->{ua} = Mojo::UserAgent->new();
  return bless $h, $class;
}


=head1 SUBROUTINES/METHODS

=cut

sub refresh_access_token {
  my ($self, $params) = @_;
  warn "Attempt to refresh access_token with params: ".Dumper $params;
  $params->{grant_type} = 'refresh_token';
  $self->{ua}->post('https://www.googleapis.com/oauth2/v4/token' => form => $params)->res->json; # tokens
};


sub client_id {
	shift->{tokensfile}->get('gapi/client_id');
}

sub ua {
  shift->{ua};
}


sub client_secret {
	shift->{tokensfile}->get('gapi/client_secret');
}


=head2 refresh_access_token_silent

Get new access token for user from Google API server and store it in jsonfile

=cut

sub refresh_access_token_silent {
	my ($self, $user) = @_;
	my $tokens = $self->refresh_access_token({
		client_id => $self->client_id,
		client_secret => $self->client_secret,
		refresh_token => $self->get_refresh_token_from_storage($user)
	});
  warn "New tokens got";
	my $res = {};
	$res->{old} = $self->get_access_token_from_storage($user);
	warn Dumper $tokens;
	if ($tokens->{access_token}) {
		$self->set_access_token_to_storage($user, $tokens->{access_token});
	}
	$res->{new} = $self->get_access_token_from_storage($user);
	return $res;
};


sub get_refresh_token_from_storage {
  my ($self, $user) = @_;
  warn "get_refresh_token_from_storage(".$user.")";
  return $self->{tokensfile}->get('gapi/tokens/'.$user.'/refresh_token');
};

sub get_access_token_from_storage {
  my ($self, $user) = @_;
  $self->{tokensfile}->get('gapi/tokens/'.$user.'/access_token');
};

sub set_access_token_to_storage {
  my ($self, $user, $token) = @_;
  $self->{tokensfile}->set('gapi/tokens/'.$user.'/access_token', $token);
};


=head2 api_query

Low-level method that can make API query to any Google service

Required params: method, route, user 

Examples of usage:

  $gapi->api_query({ 
      method => 'get', 
      route => 'https://www.googleapis.com/calendar/users/me/calendarList'',
      user => 'someuser@gmail.com'
    });

  $gapi->api_query({ 
      method => 'post', 
      route => 'https://www.googleapis.com/calendar/v3/calendars/'.$calendar_id.'/events',
      user => 'someuser@gmail.com'
  }, $json_payload_if_post);

=cut


sub api_query {
  my ($self, $params, $payload) = @_;

  warn "api_query() params : ".Dumper $params;

  my %headers = (
    'Authorization' => 'Bearer '.$self->get_access_token_from_storage($params->{user})
  );

  my $http_method = $params->{method};
  my $res;

  if ($http_method eq 'get' || $http_method eq 'delete') {

    $res = $self->{ua}->$http_method($params->{route} => \%headers)->res->json;

    # for future:
    # if ( grep { $_->{message} eq 'Invalid Credentials' && $_->{reason} eq 'authError'} @{$res->{error}{errors}} ) { ... }

    warn "First api_query() result : ".Dumper $res;

    if (defined $res->{error}) { # token expired error handling

      if ($res->{error}{message} eq 'Invalid Credentials')  {
        warn "Seems like access_token was expired. Attemptimg update it automatically ...";
        $self->refresh_access_token_silent($params->{user});
        my $t = $self->get_access_token_from_storage($params->{user});
        $headers{'Authorization'} = 'Bearer '.$t;
        warn Dumper \%headers;
        $res = $self->{ua}->$http_method($params->{route} => \%headers)->res->json;
      }

    }

    return $res;

    # warn Dumper $res->json;
    # warn Dumper $res->content->headers;


  } elsif (($http_method eq 'post') && $payload) {
    return $self->{ua}->$http_method($params->{route} => \%headers => json => $payload)->res->json;
  } else {
    die 'wrong http_method';
  }
};


1;
