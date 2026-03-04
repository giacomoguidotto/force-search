# Agent file

The purpose of this file is to describe common mistakes and confusion points that agents might encounter as they work in this project. If you ever encounter something in the project that surprises you, please alert the developer working with you and indicate that this is the case to write it in this file to help prevent future agents from having the same issue.

## Workflow

Run all three checks and fix any failures before considering the task done:

```sh
cd Scry && swift build && swift test && swiftlint
```

## Xcode Project

The Xcode project is generated from `Scry/project.yml` using XcodeGen. Re-run `xcodegen` from the `Scry/` directory whenever you add, remove, or rename source files, or change project settings. Code-only changes to existing files do not require regeneration.
