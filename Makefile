.PHONY: test lint fmt check

test:
	bats tests/

lint:
	shellcheck -x libexec/git-hookd/_hookd libexec/git-hookd/cli/*.sh bin/git-hookd modules/**/*.sh
	shfmt -d -i 0 -ci libexec/ bin/ modules/

fmt:
	shfmt -w -i 0 -ci libexec/ bin/ modules/

check: lint test
