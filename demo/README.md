# Hackathon demo

The first demo should prove one thin vertical slice rather than the complete
platform.

## Environment

Configure the demo once at the repository root:

```bash
cp .env.example .env
```

Fill in the OpenAI credentials and the single shared Turso database credentials
in that root file. All agent processes
must be launched from the kingdom root with `node --env-file=.env ...`; nested
agent `.env` files are not used.

## Primary scenario

Founder request:

> Create an educational campaign based on the most common questions from my community.

Expected evidence:

1. Orin is discovered through the registry and identifies a recurring need.
2. Scribe receives a contract-valid task and returns campaign content.
3. Rick classifies the publication action and requests founder approval.
4. The approved output and decision are written to the activity log and memory.

## Secondary scenario

Deliberately misconfigure one agent health check. Bastion should diagnose the
failure and propose a recovery action. Rick should review the proposal if it
changes production or permissions.

## Non-goals

- Public agent marketplace
- Autonomous publishing
- Automated production recovery
- General-purpose multi-agent framework
- Complex long-term memory
