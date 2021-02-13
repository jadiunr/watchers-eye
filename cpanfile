requires 'Furl';
requires 'Moo';
requires 'JSON::XS';
requires 'YAML::XS';
requires 'Net::Async::WebSocket::Client';
requires 'IO::Async::Loop';
requires 'IO::Async::SSL';
requires 'HTTP::Request::Common';
requires 'AnyEvent';
requires 'Twitter::API';

on 'develop' => sub {
  requires 'Pry';
  requires 'Term::ReadLine::Gnu';
};
