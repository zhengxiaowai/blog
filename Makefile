all: generate deploy

generate:
	hexo g

deploy:
	hexo d

clean:
	hexo clean