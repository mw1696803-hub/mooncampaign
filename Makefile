.PHONY: fmt check test build bench info

fmt:
	moon fmt

check:
	moon check

test:
	moon test

build:
	moon build

bench:
	moon bench bench/

info:
	moon info
