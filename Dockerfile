FROM 1uptalent/ruby-2.1
MAINTAINER dockerizeit@1uptalent.com

#install the agent

ENV KEEPALIVE 15
ENV REMOTE_API wss://api.dockerize.it/
ENV DOCKER_HOST unix:///docker_host/api.sock

RUN mkdir /dockerize_agent
WORKDIR /dockerize_agent

ADD Gemfile /dockerize_agent/
ADD Gemfile.lock /dockerize_agent/
RUN bundle

ADD lib /dockerize_agent/lib/
ADD start.rb /dockerize_agent/

ENTRYPOINT bundle exec ruby ./start.rb
