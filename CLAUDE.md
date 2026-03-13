# Agent file

The purpose of this file is to describe common mistakes and confusion points that agents might encounter as they work in this project. If you ever encounter something in the project that surprises you, please alert the developer working with you and indicate that this is the case to write it in this file to help prevent future agents from having the same issue.

## Workflow

Run all three checks and fix any failures before considering the task done:

```sh
cd app && xcodegen generate && xcodebuild -scheme Scry -configuration Debug build test && swiftlint
```

## Xcode Project

The Xcode project is generated from `app/project.yml` using XcodeGen. Re-run `xcodegen` from the `app/` directory whenever you add, remove, or rename source files, or change project settings. Code-only changes to existing files do not require regeneration.

## Versioning

The project uses git-tag-based semantic versioning driven by conventional commits:

- `fix:` → patch bump
- `feat:` → minor bump
- `feat!:` or `BREAKING CHANGE` → major bump

Versions come from git tags (`v*`), not source files. `scripts/bump-version.sh` computes the next semver from conventional commits and creates an annotated tag (no commits). A post-build script in `project.yml` injects the tag into the built app's Info.plist. CI auto-tags and creates GitHub Releases on `main` pushes.

**Important:** Use conventional commit prefixes (`feat:`, `fix:`, etc.) in commit messages so the version bump script can detect them.
