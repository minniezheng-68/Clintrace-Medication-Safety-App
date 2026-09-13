.PHONY: all benchmark rag_benchmark data_fetch data_list format lint test integration_tests help

# Default target executed when no arguments are given to make.
all: help

# Define a variable for the test file path.
TEST_FILE ?= tests/

test:
	uv run pytest $(TEST_FILE)

integration_tests:
	uv run pytest tests/integration_tests

benchmark:
	uv run python -m clintrace.benchmarking --output benchmark/latest.json

rag_benchmark:
	@test -n "$(KNOWLEDGE_BASE_ID)" || (echo "KNOWLEDGE_BASE_ID is required" >&2; exit 2)
	uv run python -m clintrace.rag_benchmarking \
		--knowledge-base-id "$(KNOWLEDGE_BASE_ID)" \
		--output benchmark/rag-latest.json

data_list:
	uv run python -m clintrace.open_data --list $(DATASET_IDS)

data_fetch:
	uv run python -m clintrace.open_data $(DATASET_IDS)


######################
# LINTING AND FORMATTING
######################

# Define a variable for Python and notebook files.
PYTHON_FILES=src/
MYPY_CACHE=.mypy_cache
lint format: PYTHON_FILES=.
lint_diff format_diff: PYTHON_FILES=$(shell git diff --name-only --diff-filter=d main | grep -E '\.py$$|\.ipynb$$')
lint_package: PYTHON_FILES=src
lint_tests: PYTHON_FILES=tests
lint_tests: MYPY_CACHE=.mypy_cache_test

lint lint_diff lint_package lint_tests:
	uv run ruff check $(PYTHON_FILES)
	[ "$(PYTHON_FILES)" = "" ] || uv run ruff format $(PYTHON_FILES) --check

format format_diff:
	uv run ruff format $(PYTHON_FILES)
	uv run ruff check --select I --fix $(PYTHON_FILES)

spell_check:
	codespell --toml pyproject.toml

spell_fix:
	codespell --toml pyproject.toml -w

######################
# HELP
######################

help:
	@echo '----'
	@echo 'format                       - run code formatters'
	@echo 'lint                         - run linters'
	@echo 'test                         - run unit tests'
	@echo 'tests                        - run unit tests'
	@echo 'test TEST_FILE=<test_file>   - run all tests in file'
	@echo 'benchmark                    - run the deterministic safety benchmark'
	@echo 'rag_benchmark KNOWLEDGE_BASE_ID=... - evaluate the live persistent RAG snapshot'
	@echo 'data_list                    - list pinned public dataset artifacts'
	@echo 'data_fetch DATASET_IDS=...   - download and verify selected public artifacts'
