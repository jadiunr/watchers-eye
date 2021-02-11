requires 'Furl';
requires 'Moo';
requires 'JSON::XS';
requires 'YAML::Tiny';
requires 'Net::Async::WebSocket::Client';
requires 'IO::Async::Loop';
requires 'IO::Async::SSL';
requires 'HTTP::Request::Common';

on 'develop' => sub {
  requires 'Pry';
  requires 'Term::ReadLine::Gnu';
};
