package API::Google::GCal;
use parent 'API::Google';
# use base 'API::Google';

sub new {
    my ($class, $params) = @_;
    my $self = API::Google->new($params);
    $self->{api_base} = 'https://www.googleapis.com/calendar/v3';
    bless $self, $class;
    return $self; # just for clearance
}

=head2 get_refresh_token_from_storage

get_refresh_token_from_storage using Config::JSON get() method

Usage: ```$gapi->get_calendars('pavel.p.serikov@gmail.com', ['id', 'summary']);```

=cut

sub get_calendars {
  my ($self, $user, $fields) = @_;
  my $res = $self->api_query({ 
  	method => 'get', 
  	route => $self->{api_base}.'/users/me/calendarList',
  	user => $user
  });

  if ($fields) {
    my @a;
    for my $item (@{$res->{items}}) {
        push @a, { map { $_ => $item->{$_} } grep { exists $item->{$_} } @$fields }; 
    }
    return \@a;
  } else {
    return $res;
  }
}

=head2 get_calendar_id_by_name

Name = summary parameter

=cut

sub get_calendar_id_by_name {
    my ($self, $user, $name) = @_;
    my $all = $self->get_calendars($user, ['id', 'summary']);   # arr ref
    my @n = grep { $_->{'summary'} eq $name } @$all;
    my $full_id = $n[0]->{id};
    return $full_id;
}

# https://developers.google.com/google-apps/calendar/v3/reference/events/insert

sub add_event {
    my ($self, $user, $calendar_id, $event_data) = @_;
    $self->api_query({ 
      method => 'post', 
      route => $self->{api_base}.'/calendars/'.$calendar_id.'/events',
      user => $user
    }, $event_data);
}


## Return List of time ranges during which this calendar should be regarded as busy. 


sub busy_time_ranges {
   my ($self, $params) = @_;
    $self->api_query({ 
      method => 'post', 
      route => $self->{api_base}.'/freeBusy',
      user => $params->{user}
    }, {
      timeMin => $params->{dt_start},
      timeMax => $params->{dt_end},
      timeZone => $params->{timeZone},
      items => [{ 'id' => $params->{calendar_id} }]
    });
};



1;

