.PHONY: start stop test restart

start:
	@quickshell -c mcshell &

stop:
	@quickshell kill -c mcshell 2>/dev/null || true

restart: stop
	@sleep 1
	@$(MAKE) start

test:
	@./test.sh
