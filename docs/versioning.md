# Versioning & Commits

Use conventional commit prefixes in all commit messages:

- `fix:` → patch bump
- `feat:` → minor bump
- `feat!:` or `BREAKING CHANGE` → major bump

Versions come from git tags (`v*`), not source files. `scripts/bump-version.sh` computes the next semver from conventional commits and creates an annotated tag (no commits). A post-build script in `project.yml` injects the tag into the built app's Info.plist. CI auto-tags and creates GitHub Releases on `main` pushes.
