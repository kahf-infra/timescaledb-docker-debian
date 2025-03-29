The default docker image of bitnami don't support these extensions from out of the box
- timescaledb
- vector

This docker/Dockerfile aims to overcome that limitation. The docker-compose file here to test it locally after version 
update and other changes.

Currently supported postgres versions:
- 16-debian-12(amd64)