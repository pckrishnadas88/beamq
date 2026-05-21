# BeamQ

A simple job queue built with Erlang/OTP.

## Requirements

- Erlang/OTP 27+
- rebar3 3.23+

## Start the App

```bash
rebar3 shell
```

Then in the shell:

```erlang
application:start(beamq).
```

## Testing in the Shell

### Add a job

```erlang
beamq_store:add_job(<<"hello">>).
```

### Check the queue

```erlang
ets:tab2list(jobs).
```

### Manually trigger the scheduler

```erlang
beamq_scheduler ! tick.
```

### Full test in 3 lines

```erlang
beamq_store:add_job(<<"hello">>).
beamq_scheduler ! tick.
ets:tab2list(jobs).
```

## Project Structure

```
beamq/
├── src/
│   ├── beamq_app.erl        # application entry point
│   ├── beamq_sup.erl        # supervisor
│   ├── beamq_store.erl      # job storage (ETS)
│   ├── beamq_scheduler.erl  # ticks every 1 second
│   └── beamq_worker.erl     # runs jobs
└── rebar.config
```

## Job Flow

```
add_job → ready → scheduler picks up → worker runs → done
```