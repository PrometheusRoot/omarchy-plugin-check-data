#!/usr/bin/env bash
# Before committing new bundles: aggregate the signed feed exactly as publish.yml will (sigstore-python
# against the registry identity), from the local checkout. Fails on every rejected statement except
# marketplace changes (unlisted, retired or built-in plugin, declared conflict of interest).
#   ci/selfcheck-feed.sh DATA_CHECKOUT PROVIDER_ID WORKDIR
set -Eeuo pipefail
data=${1:?} provider=${2:?} work=${3:?}
mkdir -p -- "${work}"
# A throwaway dev registry: the same provider entry (identity, windows), feed read from disk.
jq --arg p "${provider}" '.dev = true | .providers |= map(select(.id == $p) | .feedUrl = ".")' \
  "${data}/providers.json" > "${work}/providers.json"
rm -rf -- "${work}/feed" && cp -r -- "${data}/feed" "${work}/feed"
opc-collect --cache "${work}/cache" sync
opc-aggregate build --providers "${work}/providers.json" --out "${work}/out" --state "${work}/state.json" \
  --catalog "${work}/cache/marketplace/catalog.json" --registry "${work}/cache/marketplace/registry.json" > /dev/null
meta="${work}/out/api/v1/meta.json"
entries=$(jq '.entries | length' "${data}/feed/v1/index.json")
jq -e --arg p "${provider}" --argjson n "${entries}" '
  (.providers[] | select(.id == $p)) as $s
  | ($s.status == "ok" and $s.verification == "sigstore") as $ok
  | ([.rejected[] | select(.provider == $p) | .reason
      | select(test("^plugin is |\\(unlisted\\)$|conflict of interest$") | not)]) as $bad
  | if $ok and ($bad | length) == 0 and ($s.rows + ([.rejected[] | select(.provider == $p)] | length)) == $n
    then "self-check: \($s.rows) of \($n) statements verified (sigstore), feed version \($s.feedVersion)"
    else error("self-check failed: \($s) \($bad)") end' "${meta}"
