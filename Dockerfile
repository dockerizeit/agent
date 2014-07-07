FROM 1uptalent/ruby-2.1
MAINTAINER dockerizeit@1uptalent.com

#install the agent

ENV KEEPALIVE 15
ENV REMOTE_API wss://api.dockerize.it/
ENV DOCKER_HOST unix:///docker_host/api.sock
ENV DNS_MANAGER_ENABLED yes
ENV DNS_MANAGER_IMAGE dockerizeit/consul
ENV DNS_MANAGER_NAME dockerizeit_consul_main_node
ENV TUNNEL_SERVER tunnels.dockerize.it
ENV TUNNEL_CLIENT_IMAGE dockerizeit/tunnel_client

RUN mkdir /dockerize_agent
WORKDIR /dockerize_agent

ADD Gemfile /dockerize_agent/
ADD Gemfile.lock /dockerize_agent/
RUN bundle

ADD lib /dockerize_agent/lib/
ADD start.rb /dockerize_agent/

ENTRYPOINT bundle exec ruby ./start.rb
