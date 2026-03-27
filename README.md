# Github action for installing release-notes-generator tool

A Github action for installing and configuring [release-notes-generator](https://github.com/Greewil/release-notes-generator).

## Usage

If all you need is latest release-notes-generator version, simply add this to your workflow:
```yaml
- name: Install release-notes-generator
  uses: Greewil/release-notes-generator@gha/install/v1
```

If you want to install specific release-notes-generator version:
```yaml
- name: Install release-notes-generator
  uses: Greewil/release-notes-generator@gha/install/v1
  with:
    rng_version: '1.0.5'
```
Version could be '1.0.0' or 'v1.0.0'.

