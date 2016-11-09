# SYNOPSIS

    use API::Google;
    my $gapi = API::Google->new({ tokensfile => 'config.json' });
    
    $gapi->refresh_access_token_silent('someuser@gmail.com');
    
    $gapi->api_query({ 
      method => 'post', 
      route => 'https://www.googleapis.com/calendar/v3/calendars/'.$calendar_id.'/events',
      user => 'someuser@gmail.com'
    }, $event_data);
        

# SUBROUTINES/METHODS

## refresh\_access\_token\_silent

Get new access token for user from Google API server and store it in jsonfile

## api\_query

Low-level method that can make API query to any Google service

Required params: method, route, user 
