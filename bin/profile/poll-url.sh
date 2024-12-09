#!/bin/sh
# https://github.com/dgtlmoon/changedetection.io
docker run -d --restart always -p "${1:-127.0.0.1:5000:5000}" -v datastore-volume:/datastore --name changedetection.io dgtlmoon/changedetection.io
