#!/bin/bash

hey -c 1 -n 200 -host example.com http://localhost/
hey -c 1 -n 200 http://localhost/hello
hey -c 2 -n 200 http://localhost/get
hey -c 2 -n 200 http://localhost/get/204
hey -c 2 -n 200 http://localhost/get/302
hey -c 2 -n 200 http://localhost/get/404
hey -c 2 -n 200 http://localhost/get/500

hey -c 1 -n 20 -host core.spreedly.com http://localhost/v1/gateways_options.json
hey -c 1 -n 20 -host core.spreedly.com http://localhost/v1/receivers_options.json

curl -s http://localhost:8080/status | jq '.'
