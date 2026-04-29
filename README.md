# o11yfleet-load

GitHub Actions load harness for running large numbers of real OpenTelemetry Collectors against o11yFleet.

The first goal is practical calibration: run 100+ `otelcol-contrib` processes on each standard GitHub-hosted Linux runner, measure CPU and memory headroom, and then scale the runner matrix from there.

## What It Does

- Provisions one o11yFleet tenant for each run.
- Creates a main configuration group and an optional canary configuration group.
- Starts many real `otelcol-contrib` processes per runner, managed by OpAMP Supervisor by default.
- Exports hostmetrics to a real OTLP project when endpoint secrets are configured.
- Optionally rolls out a healthy config to the main group and a broken config to the canary group.
- Uploads collector logs, per-runner resource samples, generated configs, and final stats as artifacts.

The workflow defaults to `opamp_client=supervisor` because remote configuration rollout requires a client that advertises `accepts_remote_config`. Use `opamp_client=extension` only when testing direct Collector OpAMP-extension visibility without remote config acceptance.

## GitHub Secrets

Required:

- `O11YFLEET_API_URL`: worker/API base URL, for example `https://api.example.com`
- `API_SECRET`: o11yFleet programmatic admin/API secret

Optional, for sending runner hostmetrics to a real project:

- `PROJECT_OTLP_ENDPOINT`: OTLP gRPC endpoint, for example `my-project.apm.example.com:443`
- `PROJECT_OTLP_API_KEY`: API key for the OTLP endpoint

## Run A Smoke Test

Start with one runner and 25 collectors:

```bash
gh workflow run collector-load.yml \
  -f duration=10m \
  -f runners=1 \
  -f collectors_per_runner=25 \
  -f delay_start=30 \
  -f failure_percent=0
```

Then try one runner with 100 collectors:

```bash
gh workflow run collector-load.yml \
  -f duration=30m \
  -f runners=1 \
  -f collectors_per_runner=100 \
  -f delay_start=120 \
  -f failure_percent=10 \
  -f rollout_after=300 \
  -f break_after=900
```

## Scale Shape

Total collectors are:

```text
runners * collectors_per_runner
```

For example, `runners=20` and `collectors_per_runner=100` gives 2,000 real Collector processes, subject to the GitHub account's current hosted-runner concurrency.

## Local Checks

```bash
just check
```

This validates shell syntax and exercises collector config generation without requiring a live o11yFleet deployment.
