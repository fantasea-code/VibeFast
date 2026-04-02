# Encoding Rules

Use these rules for every text edit in this project.

## Required defaults

- Save text files as `UTF-8 with BOM`
- Use `CRLF` line endings
- Always keep a trailing newline at the end of the file

## Important files

- `VibeFast.ahk`
- `WebUI/index.html`
- `VibeFastSetup.iss`
- `README.md`
- `Docs/*.md`

## Collaboration note

If Gemini or any other tool edits project files, it should:

1. Preserve the existing file encoding
2. Prefer `UTF-8 with BOM` when rewriting a file
3. Avoid bulk rewrite operations unless encoding is explicit
4. Avoid mixing different save methods on the same file in the same task

## Shared workspace rule

When multiple tools or collaborators are editing the project at the same time:

1. Do not restore a file from Git just because it looks cleaner or older
2. Do not treat the Git baseline as the latest correct state by default
3. Check whether newer local workspace changes exist before using checkout or rollback
4. Prefer minimal targeted fixes over whole-file restore operations
5. If frontend or UI work is actively in progress, avoid overwriting those files from an older baseline unless the user explicitly asks for it

## Reason

This project previously had mixed historical encodings.  
Using one explicit encoding rule is the safest way to keep Chinese text stable.
