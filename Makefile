.PHONY: lint test test-unit test-integration build run_dev clean help

IMAGE_NAME	:= "ngxstats-nginx"

help:
	@echo "Available targets:"
	@echo "  lint             - Run luacheck on Lua files"
	@echo "  test             - Run all tests (unit + integration)"
	@echo "  test-unit        - Run busted unit tests only"
	@echo "  test-integration - Run Docker-based integration tests"
	@echo "  build            - Build Docker image"
	@echo "  run_dev          - Run Docker container in development mode"
	@echo "  clean            - Clean up test containers and images"
	@echo "  help             - Show this help message"

lint:
	@luacheck -q ./lib/resty

test-unit:
	@busted --verbose

test-integration:
	@./tests/integration/run-tests.sh

test: test-unit test-integration

build: Dockerfile
	docker build --no-cache -t $(IMAGE_NAME) .

run_dev: Dockerfile
	docker run \
		-v $(shell pwd)/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf \
		-v $(shell pwd)/lib/resty:/etc/nginx/lua/stats \
		--rm -p 80:80 -p 81:81 -p 8080:8080 -it $(IMAGE_NAME)

clean:
	@docker compose -f tests/integration/docker-compose.yml down -v --remove-orphans 2>/dev/null || true
	@docker rmi -f ngxstats-nginx ngxstats-test 2>/dev/null || true
	@echo "Cleanup complete"
