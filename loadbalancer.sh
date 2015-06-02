#!/bin/bash

apt-get update -q
apt-get -q install -y haproxy

APP_IP=${APP_IP:-127.0.0.1}

cat >/etc/haproxy/haproxy.cfg <<EOL
global
maxconn     4096 # Total Max Connections. This is dependent on ulimit
daemon
defaults
mode        http
option      forwardfor # send the original ip to the backends
clitimeout  360000
srvtimeout  360000
contimeout  4000

listen http_example 0.0.0.0:80 inter 5s
mode http
balance leastconn
cookie COOKIE insert indirect nocache
server SERVER1 $APP_IP:80 cookie SERVER1 weight 30 check

listen admin_page :8080
mode http
stats uri /st4ts
stats realm HAProxy
stats auth admin:password
EOL

echo "ENABLED=1" > /etc/default/haproxy

/etc/init.d/haproxy restart                                        

