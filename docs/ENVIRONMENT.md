# Shared hackathon environment

The all-in-one hackathon assembly uses exactly one environment file:

```text
sleeping-prince/.env
```

Do not create `.env` files inside `agents/orin`, `agents/scribe`, `agents/rick`,
or `agents/bastion`. The root `.env.example` is the committed configuration
contract. The root `.env` contains local credentials and is ignored by Git.

## Loading convention

Every agent runtime reads configuration from `process.env`. Agent code must not
resolve or load an agent-local `.env` file.

During local development, launch each compiled Node.js entrypoint from the
kingdom root and load the root file explicitly:

```bash
node --env-file=.env agents/orin/dist/index.js
node --env-file=.env agents/scribe/dist/index.js
node --env-file=.env agents/rick/dist/index.js
node --env-file=.env agents/bastion/dist/index.js
```

These commands are the target runtime convention; agent entrypoints are not
implemented yet.

In a process manager or container deployment, inject the same variable names
through the platform rather than copying `.env` into an image.

## Variable ownership

| Owner      | Variables                                                                           |
| ---------- | ----------------------------------------------------------------------------------- |
| All agents | `NODE_ENV`, `LOG_LEVEL`, `OPENAI_API_KEY`, `TURSO_DATABASE_URL`, `TURSO_AUTH_TOKEN` |
| Orin       | `ORIN_PORT`                                                                         |
| Scribe     | `SCRIBE_PORT`                                                                       |
| Rick       | `RICK_PORT`                                                                         |
| Bastion    | `BASTION_PORT`                                                                      |

For hackathon speed, all agents connect to the same Turso database with the same
credentials. Agent memory is separated by table rather than by database:

| Table              | Owner                         |
| ------------------ | ----------------------------- |
| `orin_memories`    | Orin                          |
| `scribe_memories`  | Scribe                        |
| `rick_memories`    | Rick                          |
| `bastion_memories` | Bastion                       |
| `shared_memories`  | Kingdom-wide sanitized memory |
| `workflow_runs`    | Kingdom workflow state        |
| `approval_records` | Founder and Rick decisions    |
| `audit_events`     | Append-only activity history  |

Agent code should access only its own memory table plus explicitly permitted
shared tables. This is an application-level convention for the hackathon, not a
hard database security boundary.
