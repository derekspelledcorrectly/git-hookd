.PHONY: test lint fmt check

TEST_DIRS := tests/dispatcher tests/cli tests/modules

test:
	bats $(TEST_DIRS)

lint:
	shellcheck -x libexec/git-hookd/_hookd libexec/git-hookd/cli/*.sh bin/git-hookd modules/**/*.sh
	shfmt -d -i 0 -ci libexec/ bin/ modules/

fmt:
	shfmt -w -i 0 -ci libexec/ bin/ modules/

check: lint test
