#!/bin/bash

apt-get update
apt-get install -y curl software-properties-common apt-transport-https socat golang-1.9 rsync
curl -Lo hugo_0.49.2_Linux-64bit.deb https://github.com/gohugoio/hugo/releases/download/v0.49.2/hugo_0.49.2_Linux-64bit.deb
dpkg -i hugo_0.49.2_Linux-64bit.deb
add-apt-repository -y ppa:git-core/ppa
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial edge" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get -y install docker-ce git
