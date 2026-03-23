.PHONY: test lint fmt check install uninstall

TEST_DIRS := tests/dispatcher tests/cli tests/modules

test:
	bats $(TEST_DIRS)

lint:
	shellcheck -x libexec/git-hookd/_hookd libexec/git-hookd/cli/*.sh bin/git-hookd modules/**/*.sh install.sh
	shfmt -d -i 0 -ci libexec/ bin/ modules/ install.sh

fmt:
	shfmt -w -i 0 -ci libexec/ bin/ modules/ install.sh

check: lint test

install:
	./bin/git-hookd install

uninstall:
	./bin/git-hookd uninstall
