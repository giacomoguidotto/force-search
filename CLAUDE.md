# Agent file

The purpose of this file is to describe common mistakes and confusion points that agents might encounter as they work in this project. If you ever encounter something in the project that surprises you, please alert the developer working with you and indicate that this is the case to write it in this file to help prevent future agents from having the same issue.

## Workflow

Run all three checks and fix any failures before considering the task done:

```sh
cd Scry && swift build && swift test && swiftlint
```

## Xcode Project

The Xcode project is generated from `Scry/project.yml` using XcodeGen. Re-run `xcodegen` from the `Scry/` directory whenever you add, remove, or rename source files, or change project settings. Code-only changes to existing files do not require regeneration.

## Versioning

The project uses git-tag-based semantic versioning driven by conventional commits:

- `fix:` → patch bump
- `feat:` → minor bump
- `feat!:` or `BREAKING CHANGE` → major bump

`Scripts/bump-version.sh` reads the latest `v*` tag, scans commits since then, and computes the next version. It updates `CFBundleShortVersionString` in both `Scry/project.yml` and `Scry/Scry/App/Info.plist`, then creates an annotated tag. Use `--dry-run` to preview without changes.

The CI `version` job in `.github/workflows/ci.yml` runs this script on `main` pushes after build+test, pushes the tag, and creates a GitHub Release.

The version is displayed in the onboarding panel via `Bundle.main.infoDictionary["CFBundleShortVersionString"]`.

**Important:** Use conventional commit prefixes (`feat:`, `fix:`, etc.) in commit messages so the version bump script can detect them.
