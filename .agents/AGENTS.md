# Git and PR style rules

*   **No generic headers at the top**: Do not use generic headers like `# Summary` or `### Summary` at the very beginning of commit messages or PR descriptions.
*   **Useful first line**: The first line of a commit message or PR description must be the actual summary of the changes. This ensures that command-line commit logs (e.g., `git log --oneline`) and GitHub PR list previews are useful and scannable.
*   **No agent metadata**: Do not attach agent metadata (such as `TAG=agy` or `CONV=...`) to PR descriptions or commit messages. Keep these descriptions clean and human-readable.
*   **Avoid force-pushing**: Highly discourage force-pushing to branches that have active pull requests under review. Force-pushing rewrites history and dislocates code review comments, making them difficult to track. Prefer adding incremental commits to address feedback. Only force-push if explicitly requested or during initial draft setup before review has started.
*   **Commit scopes**: When using Conventional Commits, use one of the following scopes if the change is specific to a module or area. Scopes are optional but restricted to:
    *   `rules`: Custom Starlark rules, aspects, and macro definitions ([rules/](rules/) directory).
    *   `pkg`: Sample protobuf definitions and Go target configurations ([pkg/](pkg/) directory).
    *   `engprod`: Developer tools, CI/CD workflows, and repo-level configs ([.github/](.github/), `.bcr/`).

# Language and tone style rules

*   **Style guide**: Adhere to the [Google Developer Documentation Style Guide](https://developers.google.com/style) for general writing style, tone, and formatting (e.g., use sentence case for all headings and list items).
*   **External references**: When referencing a specification, standard, or official documentation, err on the side of including a link to the external resource in the documentation or comments. This allows the reader to easily verify and consult the reference.
*   **Plain and understated language**: Use plain, direct, and understated language. Avoid marketing-speak, exaggerations, and hyperbole (e.g., do not use words like "beautifully", "extremely", "perfectly", "easily" unless they are factually verifiable and necessary).
*   **Minimal jargon**: Keep technical jargon to a minimum. Explain concepts simply and clearly.
*   **No unnecessary capitalization**: Do not capitalize words unnecessarily. Only capitalize proper nouns, the first word of a sentence, or well-established acronyms. Avoid capitalizing general terms (e.g., prefer "pull request" over "Pull Request", "versioning policy" over "Versioning Policy" in body text, unless they are headings).

# Go style rules

Adhere strictly to the following style guides. If they conflict, the more restrictive rule (usually from the Uber guide) takes precedence:
*   [Effective Go](https://go.dev/doc/effective_go) — For foundational idioms and writing "natural" Go.
*   [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments) — For official style corrections (e.g., package comments, error formatting).
*   [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md) — For strict production safety, concurrency guidelines, and performance patterns.
