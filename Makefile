.PHONY: start stop test restart

start:
	@mcs-qs -c mcshell &

stop:
	@kill $$(pgrep -x qs) 2>/dev/null || true

restart: stop
	@sleep 1
	@$(MAKE) start

test:
	@./test.sh
