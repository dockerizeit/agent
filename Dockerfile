FROM ubuntu:12.04
MAINTAINER support@dockerize.it

# install ruby dependencies
RUN apt-get update
RUN apt-get install -y build-essential
RUN apt-get install -y libssl-dev
RUN apt-get install -y libreadline-dev
RUN apt-get install -y libffi-dev
RUN apt-get install -y libgdbm-dev

# Install IRB configuration
ADD irbrc /.irbrc

# install ruby from sources
ADD http://cache.ruby-lang.org/pub/ruby/2.1/ruby-2.1.1.tar.bz2 /
RUN tar xvjf ruby-2.1.1.tar.bz2 && cd ruby-2.1.1 && ./configure --disable-install-doc --with-openssl-dir=/usr/bin && make && make install && cd / && rm -rf /ruby-2.1.1

# install Bundler
RUN gem install bundler --version 1.5.2

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
