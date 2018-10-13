#!/bin/bash

apt-get update
apt-get install -y curl apt-transport-https git socat golang-1.9
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial edge" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get -y install docker-ce
