# Exylia-Plugins/.github

Shared GitHub Actions for the Exylia plugins.

## Modrinth

`.github/workflows/modrinth.yml` mirrors a GitHub release to Modrinth. It downloads the jar and the
release notes from the calling repository's `v<version>` release, so call it after the job that
creates that release:

```yaml
  modrinth:
    needs: release
    uses: Exylia-Plugins/.github/.github/workflows/modrinth.yml@main
    with:
      version: ${{ github.ref_name }}            # v1.2.0 or 1.2.0; a leading v is stripped
      name: ExyliaDisplays                       # asset ExyliaDisplays-<version>.jar
      project-id: ${{ vars.MODRINTH_PROJECT_ID }}
      loaders: '["folia","paper","purpur"]'
      dependencies: '[{"project_id":"G0BDxMIG","dependency_type":"required"}]'
    secrets: inherit
```

| Input | Default | |
|---|---|---|
| `version` | required | `1.2.0` or `v1.2.0`; the release tag is `v<version>` |
| `name` | required | Display name; the version is named `<name> <version>` |
| `jar` | `<name>-<version>.jar` | Release asset pattern; must match exactly one file |
| `project-id` | empty | Modrinth id or slug; empty skips with a notice |
| `loaders` | `["folia","paper","purpur"]` | JSON array |
| `game-versions` | the list in `publish-modrinth.sh` | JSON array |
| `dependencies` | `[]` | JSON array of `{"project_id","dependency_type"}` |

Secret `MODRINTH_TOKEN` (a PAT with Create versions, Read projects, Read versions); missing skips
with a notice. A version number Modrinth already has is skipped, so re-runs never duplicate.

## BuiltByBit

`.github/workflows/builtbybit.yml` mirrors the same release to BuiltByBit (v2 Creator API): it uploads
the jar as a new version and posts the public update, listing the `feat`/`fix`/`perf` commits since the
previous tag. Call it next to the Modrinth job:

```yaml
  builtbybit:
    needs: release
    uses: Exylia-Plugins/.github/.github/workflows/builtbybit.yml@main
    with:
      version: ${{ github.ref_name }}
      name: ExyliaDisplays                       # asset ExyliaDisplays-<version>.jar
      resource-id: ${{ vars.BBB_RESOURCE_ID }}
    secrets: inherit
```

| Input | Default | |
|---|---|---|
| `version` | required | `1.2.0` or `v1.2.0`; the release tag is `v<version>` |
| `name` | required | Display name; the update is titled `<name> v<version>` |
| `jar` | `<name>-<version>.jar` | Release asset pattern; must match exactly one file |
| `resource-id` | empty | BuiltByBit resource id; empty skips with a notice |
| `post-update` | `true` | `false` uploads the version without the public update post |

Secret `BUILTBYBIT_TOKEN` (a Private API token, Ultimate account); missing skips with a notice. A
version BuiltByBit already lists is skipped, so re-runs never duplicate. By hand:
`BUILTBYBIT_TOKEN=... BBB_RESOURCE=<id> ./publish-builtbybit.sh <name> <version> <jar> [changes-file]`.

## By hand

```sh
gh release download v1.2.0 --repo Exylia-Plugins/ExyliaDisplays --pattern 'ExyliaDisplays-1.2.0.jar'
gh release view v1.2.0 --repo Exylia-Plugins/ExyliaDisplays --json body --jq .body > changelog.md
MODRINTH_TOKEN=... MODRINTH_PROJECT=exyliadisplays \
DEPENDENCIES='[{"project_id":"G0BDxMIG","dependency_type":"required"}]' \
  ./publish-modrinth.sh ExyliaDisplays 1.2.0 ExyliaDisplays-1.2.0.jar changelog.md
```
