.PHONY: lint
IMAGE_NAME	:= "ngxstats-nginx"

lint:
	@luacheck -q ./lib/resty

build: Dockerfile
	docker build --no-cache -t $(IMAGE_NAME) .

run_dev: Dockerfile
	docker run \
		-v $(shell pwd)/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf \
		-v $(shell pwd)/lib/resty:/etc/nginx/lua/stats \
		--rm -p 80:80 -p 81:81 -p 8080:8080 -it $(IMAGE_NAME)
