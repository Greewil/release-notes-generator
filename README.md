# Github action for generating release based on commits

A Github action for generating release with release notes based on commits (or just release notes) using [generate-release-notes](https://github.com/Greewil/generate-release-notes).

# Usage

If all you need is just created release with release netes inside, simply add this to you workflow:
```yaml
- name: Generate release with release-notes-generator
  uses: Greewil/release-notes-generator@gha/generate-release-notes/v1
  with:
    create_release: 'true'
    tag_name: "v1.0.0"
```

If you want to just generate relese notes without publishing release:
```yaml
- name: Generate release with release-notes-generator
  uses: Greewil/release-notes-generator@gha/generate-release-notes/v1
```

### Input parameters

All input parameters:
```yaml
inputs:
  rng_version:
    description: "Release Notes Generator version"
    required: false
    type: string
  create_release:
    description: "Whether to create a GitHub Release"
    required: false
    default: "false"
    type: boolean
  tag_name:
    description: "The name of the tag for the release"
    required: false
    type: string
```

### Outputs

All outputs:
```yaml
outputs:
  changelog:
    description: "Generated changelog content"
    value: ${{ steps.changelog.outputs.FINAL_CHANGELOG }}
  is_empty:
    description: "True if changelog is empty"
    value: ${{ steps.changelog.outputs.IS_EMPTY }}
```

