# Contributing

Thanks for your interest in improving this project.

## Reporting issues

Open an issue at <https://github.com/drvpereira/claude-context/issues>. Include:

- What you expected Claude to do and what it actually did
- The file(s) involved (agent, skill, convention or workflow)
- Your Claude Code version, and the stack of the workspace you used it in

**Never paste secrets, internal URLs, or proprietary code** into an issue. Reduce the example to something neutral first.

## Proposing changes

For anything beyond a small fix (a new agent or skill, a change to the workflow phases or gates), open an issue first so the approach can be agreed before you invest time in it.

## Pull requests

1. Fork the repo and create a branch from `main` (`feature/<short-desc>` or `hotfix/<short-desc>`).
2. Keep each PR focused on one logical change.
3. Follow the existing structure:
   - Skills live in `.claude/skills/<kebab-name>/SKILL.md`, with `name` and `description` frontmatter.
   - Agents live in `.claude/agents/<role>.md`.
   - Register new skills in the Skills table in `CLAUDE.md` and in the README.
4. Keep the content **generic**. Use neutral examples (`example.com`, `com.example.*`, Orders/Customers domains) and placeholders (`{team-email}`), never real company names, hosts or ticket IDs.
5. Check Markdown links and anchors still resolve, and that `setup.sh` still runs (`bash -n setup.sh`).
6. Describe *why* the change helps in the PR description.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
