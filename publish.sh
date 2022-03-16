#!/bin/bash

echo $REPOSITORY_PASSWORD | docker login -u $REPOSITORY_USER  --password-stdin

docker-compose -f ./iac/docker-compose.yml push
