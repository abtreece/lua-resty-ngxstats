#!/bin/bash

hey -c 1 -n 200 -host example.com http://localhost/
hey -c 1 -n 200 http://localhost/hello
hey -c 2 -n 200 http://localhost/get
hey -c 2 -n 200 http://localhost/get/204
hey -c 2 -n 200 http://localhost/get/302
hey -c 2 -n 200 http://localhost/get/404
hey -c 2 -n 200 http://localhost/get/500

echo ""
echo "=== Prometheus Metrics ==="
curl -s http://localhost:8080/status
