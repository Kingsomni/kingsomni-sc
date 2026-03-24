# Kingsomni Reactivity Scripts

## Commands

- `npm.cmd run setup`
  - Create 2 on-chain subscriptions (Profile + Treasury)
  - Prints transaction hash and subscription ID(s)

- `npm.cmd run list-ids`
  - Lists active subscription IDs for `OWNER_ADDRESS` (or from `PRIVATE_KEY`)

- `npm.cmd run check`
  - Checks subscription details by `SUBSCRIPTION_IDS`

- `npm.cmd run unsubscribe`
  - Cancels subscriptions by `SUBSCRIPTION_IDS`
  - Use `DRY_RUN=true` first

## Required `.env`

- `PRIVATE_KEY`
- `HANDLER_ADDRESS`
- `PROFILE_ADDRESS`
- `TREASURY_ADDRESS`

## Optional `.env`

- `PRIORITY_FEE_GWEI` (default `0`)
- `MAX_FEE_GWEI` (default `10`)
- `SUBSCRIPTION_GAS_LIMIT` (default `3000000`)
- `OWNER_ADDRESS`
- `SUBSCRIPTION_FROM_BLOCK`
- `LOG_BLOCK_SPAN` (default `900`)
- `SUBSCRIPTION_IDS` (for `check` and `unsubscribe`)
- `DRY_RUN` (for `unsubscribe`, default `false`)
- `SKIP_OWNER_CHECK` (for `unsubscribe`, default `false`)
