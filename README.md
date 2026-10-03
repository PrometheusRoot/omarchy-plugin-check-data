# omarchy-plugin-check-data

Published data of [omarchy-plugin-check](https://github.com/PrometheusRoot/omarchy-plugin-check):
our provider feed (`opc`) and the signed store snapshot that the checker plugin, the store app and
the [site](https://prometheusroot.github.io/omarchy-plugin-check/) read. Independent community
project, not affiliated with Omarchy. How it works: the tool's ADR-0039, `spec/PROTOCOL.md` and
`docs/RUNBOOK.md`.

| What | Where | Signed by |
|---|---|---|
| Provider feed `opc` (in-toto statements + index) | [`feed/v1/`](feed/v1/), served from `https://raw.githubusercontent.com/PrometheusRoot/omarchy-plugin-check-data/master/feed/v1/` | Sigstore keyless, [`sign.yml`](.github/workflows/sign.yml) on `refs/heads/master` |
| Provider registry source | [`providers.json`](providers.json) (unsigned; `publish.yml` stamps version + expiry and signs it) | production ed25519 key |
| Snapshot, store client bundle, static API, registry | <https://prometheusroot.github.io/omarchy-plugin-check-data/> (latest, per file) | production ed25519 key, [`publish.yml`](.github/workflows/publish.yml) |
| Every published snapshot | [Releases](https://github.com/PrometheusRoot/omarchy-plugin-check-data/releases) `snapshot-<version>`: `snapshot.tar.gz`, the signed files, `SHA256SUMS` (immutable) | same |

## Verify the snapshot

The production key (`SHA256:pjXUzN+57yC2zez/zQd1BGKfnY5eopJDJH1GJLop8vQ`) is committed in the tool
repository as `spec/keys/allowed_signers`; take it from there, not from this repository.

```sh
curl -fsSLo allowed_signers https://raw.githubusercontent.com/PrometheusRoot/omarchy-plugin-check/master/spec/keys/allowed_signers
b=https://prometheusroot.github.io/omarchy-plugin-check-data
curl -fsSLO "$b/store.json" -fsSLO "$b/store.json.sig"
ssh-keygen -Y verify -f allowed_signers -I omarchy-plugin-check -n omarchy-plugin-check-snapshot \
  -s store.json.sig < store.json
jq '{version, expires, dev, plugins: (.plugins | length)}' store.json    # parse only after it verifies
```

`store-manifest.json` verifies the same way and lists the sha256 and size of every bundle file;
`providers.json` uses the namespace `omarchy-plugin-check-providers`. Clients also reject an
expired snapshot (`expires`, 7 days) and a `version` lower than the last one they accepted. The
checker does all of this: `omarchy-plugin-check update`.

## Verify our feed

Each `statements/<plugin id>/<commit>.sigstore.json` is a DSSE bundle carrying the statement next
to it; `index.json.sigstore.json` signs `index.json`. Both must come from this repository's
`sign.yml` on master:

```sh
cosign verify-blob --bundle feed/v1/index.json.sigstore.json \
  --certificate-identity https://github.com/PrometheusRoot/omarchy-plugin-check-data/.github/workflows/sign.yml@refs/heads/master \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com feed/v1/index.json
```

The aggregator verifies every bundle the same way with sigstore-python (exact identity, issuer and
repository from the signed registry) before a verdict reaches the snapshot.

## How it changes

- New reviews: the owner commits unsigned statements (`opsec feed` output) under
  `feed/v1/statements/`. `sign.yml` validates them (`opc-feed check`), signs each one once
  (statements are immutable), rebuilds and signs the index, commits only the bundles and the index,
  and starts `publish.yml`. It runs only for pushes to master by the owner, by hand, and weekly to
  renew the index; never on pull requests.
- Daily `publish.yml`: marketplace + GitHub collection, aggregation, ranking, signing in a job
  that runs only `ssh-keygen`, verification with the published key, Pages + an immutable release.
- Security reports: <https://github.com/PrometheusRoot/omarchy-plugin-check/security/advisories/new>
  (private vulnerability reporting).

## License

The data is [CC BY 4.0](LICENSE) (full legal code): credit "omarchy-plugin-check,
https://github.com/PrometheusRoot/omarchy-plugin-check". Quoted Omarchy marketplace metadata
(names, descriptions, images, links) stays under its owners' terms. A verdict is a statement about
one commit at one time, not a warranty. The workflow and `ci/` scripts are MIT, like the tool.
