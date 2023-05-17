requires 'Furl';
requires 'Moo';
requires 'JSON::XS';
requires 'YAML::XS';
requires 'AnyEvent';
requires 'AnyEvent::WebSocket::Client';
requires 'HTTP::Request::Common';
requires 'Twitter::API';
requires 'HTML::Entities';
requires 'Parallel::ForkManager';

on 'develop' => sub {
  requires 'Pry';
  requires 'Term::ReadLine::Gnu';
};
