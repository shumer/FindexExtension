#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
for script in build.sh run-tests.sh scripts/*.sh; do bash -n "$script"; done
ruby -ryaml -e 'ARGV.each { |path| YAML.load_file(path) }; puts "YAML syntax valid."' .github/workflows/*.yml
python3 scripts/check-source.py
