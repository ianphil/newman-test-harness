#!/bin/bash

apt update
apt upgrade -y
curl -fsSL https://get.docker.com | sh
usermod -aG docker azusr

docker run -d --rm -p 8080:8080 tripdubroot/sampleresponse:001