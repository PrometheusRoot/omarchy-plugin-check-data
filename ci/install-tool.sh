#!/usr/bin/env bash
# Install the public tool (spec, aggregator, collector) from a checkout at the pinned commit into a
# venv, with every third-party dependency hash-pinned by ci/requirements.lock; put it on PATH.
#   ci/install-tool.sh TOOL_CHECKOUT
set -Eeuo pipefail
tool=${1:?usage: install-tool.sh TOOL_CHECKOUT}
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
venv="${RUNNER_TEMP:?}/venv"
python3 -m venv "${venv}"
"${venv}/bin/pip" install -q --disable-pip-version-check --require-hashes --no-deps -r "${here}/requirements.lock"
"${venv}/bin/pip" install -q --disable-pip-version-check --no-deps --no-build-isolation "${tool}/spec" "${tool}/aggregator" "${tool}/collector"
"${venv}/bin/pip" check
echo "${venv}/bin" >> "${GITHUB_PATH:?}"
