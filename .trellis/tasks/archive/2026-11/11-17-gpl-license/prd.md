# Align GPL v3 licensing with the main project

## Goal

Copy verified GPL v3 text, align README licensing, commit and push before continuing full-app CI.

## Requirements

- Copy the complete GPL v3 LICENSE from D:/MyNewProjects/qflistudio.
- Align English, Simplified Chinese and Traditional Chinese README license sections.
- Preserve separate Lua, QuickJS and TypeScript license notices.
- Use Conventional Commits and push to the existing GitHub CI branch.
- Exclude user changes, sibling repositories and app runtime source.

## Acceptance Criteria

- LICENSE matches GNU official text: 35149 bytes, SHA256 3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986.
- README links resolve and changed Chinese prose passes controlled-language lint.
- Commit is pushed and remote branch equals the local revision.

## Notes

- The user explicitly requested this prerequisite, commit and push before further application build work.
- Main project LICENSE exactly matched the GNU text during read-only verification.
