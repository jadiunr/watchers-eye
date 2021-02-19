requires 'Furl', '==3.13';
requires 'Moo', '==2.004004';
requires 'JSON::XS', '==4.03';
requires 'YAML::XS', '==0.82';
requires 'AnyEvent', '==7.17';
requires 'AnyEvent::WebSocket::Client', '==0.53';
requires 'HTTP::Request::Common', '==6.27';
requires 'Twitter::API', '==1.0005';
requires 'HTML::Entities', '==3.75';

on 'develop' => sub {
  requires 'Pry';
  requires 'Term::ReadLine::Gnu';
};
