package API::Google;

# ABSTRACT: Perl library for easy access to Google services via their API

=head1 SYNOPSIS

    use API::Google;
    my $gapi = API::Google->new({ tokensfile => 'config.json' });
    
    $gapi->refresh_access_token_silent('someuser@gmail.com');
    
    $gapi->api_query({ 
      method => 'post', 
      route => 'https://www.googleapis.com/calendar/v3/calendars/'.$calendar_id.'/events',
      user => 'someuser@gmail.com'
    }, $event_data);
	
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
  warn Dumper $params;
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
  $self->{tokensfile}->get('gapi/tokens/'.$user.'/refresh_token');
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

=cut


sub api_query {
  my ($self, $params, $payload) = @_;
  my %headers = (
    'Authorization' => 'Bearer '.$self->get_access_token_from_storage($params->{user})
  );
  my $http_method = $params->{method};
  if ($http_method eq 'get') {
    return $self->{ua}->$http_method($params->{route} => \%headers)->res->json;
  } elsif (($http_method eq 'post') && $payload) {
    return $self->{ua}->$http_method($params->{route} => \%headers => json => $payload)->res->json;
  } else {
    die 'wrong http_method';
  }
};


1;
