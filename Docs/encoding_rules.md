# Encoding Rules

Use these rules for every text edit in this project.

## Required defaults

- Save text files as `UTF-8 with BOM`
- Use `CRLF` line endings
- Always keep a trailing newline at the end of the file

## Important files

- `FastKey.ahk`
- `WebUI/index.html`
- `FastKeySetup.iss`
- `README.md`
- `Docs/*.md`

## Collaboration note

If Gemini or any other tool edits project files, it should:

1. Preserve the existing file encoding
2. Prefer `UTF-8 with BOM` when rewriting a file
3. Avoid bulk rewrite operations unless encoding is explicit
4. Avoid mixing different save methods on the same file in the same task

## Reason

This project previously had mixed historical encodings.  
Using one explicit encoding rule is the safest way to keep Chinese text stable.
