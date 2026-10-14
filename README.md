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
      version: ${{ needs.release.outputs.version }}  # no leading v
      name: ExyliaDisplays                       # asset ExyliaDisplays-<version>.jar
      project-id: ${{ vars.MODRINTH_PROJECT_ID }}
      loaders: '["folia","paper","purpur"]'
      dependencies: '[{"project_id":"G0BDxMIG","dependency_type":"required"}]'
    secrets: inherit
```

The release job exposes the version as an output, e.g. a step with `id: version` running
`echo "version=${GITHUB_REF_NAME#v}" >> "$GITHUB_OUTPUT"` and
`outputs: { version: ${{ steps.version.outputs.version }} }` on the job.

| Input | Default | |
|---|---|---|
| `version` | required | Release tag is `v<version>` |
| `name` | required | Display name; the version is named `<name> <version>` |
| `jar` | `<name>-<version>.jar` | Release asset pattern; must match exactly one file |
| `project-id` | empty | Modrinth id or slug; empty skips with a notice |
| `loaders` | `["folia","paper","purpur"]` | JSON array |
| `game-versions` | the list in `publish-modrinth.sh` | JSON array |
| `dependencies` | `[]` | JSON array of `{"project_id","dependency_type"}` |

Secret `MODRINTH_TOKEN` (a PAT with Create versions, Read projects, Read versions); missing skips
with a notice. A version number Modrinth already has is skipped, so re-runs never duplicate.

## By hand

```sh
gh release download v1.2.0 --repo Exylia-Plugins/ExyliaDisplays --pattern 'ExyliaDisplays-1.2.0.jar'
gh release view v1.2.0 --repo Exylia-Plugins/ExyliaDisplays --json body --jq .body > changelog.md
MODRINTH_TOKEN=... MODRINTH_PROJECT=exyliadisplays \
DEPENDENCIES='[{"project_id":"G0BDxMIG","dependency_type":"required"}]' \
  ./publish-modrinth.sh ExyliaDisplays 1.2.0 ExyliaDisplays-1.2.0.jar changelog.md
```
