.PHONY: lint test build run_dev help

IMAGE_NAME	:= "ngxstats-nginx"

help:
	@echo "Available targets:"
	@echo "  lint      - Run luacheck on Lua files"
	@echo "  test      - Run busted unit tests"
	@echo "  build     - Build Docker image"
	@echo "  run_dev   - Run Docker container in development mode"
	@echo "  help      - Show this help message"

lint:
	@luacheck -q ./lib/resty

test:
	@busted --verbose

build: Dockerfile
	docker build --no-cache -t $(IMAGE_NAME) .

run_dev: Dockerfile
	docker run \
		-v $(shell pwd)/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf \
		-v $(shell pwd)/lib/resty:/etc/nginx/lua/stats \
		--rm -p 80:80 -p 81:81 -p 8080:8080 -it $(IMAGE_NAME)
