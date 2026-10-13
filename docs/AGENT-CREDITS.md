# Agent credits on GitHub

The README shows the verified agent roles from [AUTHORS.md](../AUTHORS.md).
GitHub builds its contributor displays from commit records and linked accounts.
An entry in AUTHORS.md does not create a GitHub contributor.

## Credit the actual contributor

Use a co-author trailer when an agent helped produce the change in that commit.
Keep the human maintainer as the commit author when the maintainer integrates it.
Record the actual model and its role in the PR when launch evidence proves them.
Credit independent review in the review report. Review alone does not make the
reviewer a co-author of the reviewed change.

Do not change shared Git identity. Do not invent account emails.
Do not add an agent to a commit only to obtain an avatar.
Preserve reviewed commit hashes and historical credits.

## Verified account identities

On 2026-10-12, the GitHub user API returned these account identities:

| Agent | Account | Numeric ID | Public profile |
| --- | --- | --- | --- |
| Codex | `codex` | `267193182` | OpenAI, with a link to openai.com/codex |
| Claude | `claude` | `81847` | Anthropic, with a link to anthropic.com/claude-code |

Use the ID-based GitHub email for the actual contributor:

```text
Co-authored-by: Codex <267193182+codex@users.noreply.github.com>
```

```text
Co-authored-by: Claude <81847+claude@users.noreply.github.com>
```

The Claude example is an instruction for a future Claude-authored change.
It does not credit Claude for work in this project.
An account credit does not identify the exact model. Keep model evidence separate.
Check the account identity again before you use an email on a new contribution.

No verified account-linked email was established for Kimi or Qwen in this check.
Keep their verified research credits in the README and AUTHORS.md.
Do not assume that an account named `kimi` or `qwen` belongs to the model provider.
Moonshot's open requests ask for an official Kimi co-author identity and avatar.
Those requests do not establish an identity for this project.

## References

- [GitHub contributor rules](https://docs.github.com/en/repositories/viewing-activity-and-data-for-your-repository/viewing-a-projects-contributors)
- [GitHub co-author instructions](https://docs.github.com/en/pull-requests/committing-changes-to-your-project/creating-and-editing-commits/creating-a-commit-with-multiple-authors)
- [GitHub ID-based commit emails](https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-user-account/managing-email-preferences/setting-your-commit-email-address)
- [Codex account](https://github.com/codex) and [user API](https://api.github.com/users/codex)
- [Claude account](https://github.com/claude) and [user API](https://api.github.com/users/claude)
- [Kimi identity request](https://github.com/MoonshotAI/Kimi-K2.5/issues/2)
- [Kimi avatar request](https://github.com/MoonshotAI/kimi-cli/issues/2256)
