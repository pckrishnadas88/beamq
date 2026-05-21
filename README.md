# BeamQ

A thread-safe, event-driven distributed background job queue built with Erlang/OTP. 

Designed for deep learning of OTP fundamentals, process isolation, and explicit state management without the throughput bottlenecks of naive timer loops.

## Core Architecture Concepts

* **Atomic Checkout:** Grabbing a job and marking it as `running` happens inside a single, isolated transaction in the `beamq_store` process, making duplicate delivery physically impossible.
* **Demand-Driven Dispatching:** The scheduler doesn't look at a clock to process work. It dynamically spawns workers when new jobs arrive or when a running worker finishes and opens up a processing slot.
* **Strict Concurrency Capping:** Enforces a hard limit on simultaneous background processes (`MAX_CONCURRENT_JOBS`) to protect your resources from crashing under heavy load.

## Requirements

- Erlang/OTP 27+
- rebar3 3.23+

## Start the App

```bash
rebar3 shell

```

Then in the shell, start the OTP application tree:

```erlang
1> application:start(beamq).
ok

```

## Testing Ecosystem Flow

### 1. Add Jobs Simultaneously

Add multiple jobs to the system at the exact same time. The scheduler will automatically capture the signal, allocate slots up to your concurrency maximum, and queue the rest safely.

```erlang
2> beamq_store:add_job(#{task => "send_welcome_email", user_id => 101}).
1
3> beamq_store:add_job(#{task => "render_video_clip", asset_id => 404}).
2
4> beamq_store:add_job(#{task => "sync_analytics"}).
3

```

### 2. Check Active Engine State

Inspect the underlying ETS tables to observe the real-time explicit state updates of the running architecture:

```erlang
5> ets:tab2list(jobs).

```

### 3. Simulating Failure and Backoff (Phase 2 Testing)

To view the error capture and non-blocking asynchronous exponential backoff mechanism in action, queue a job explicitly carrying a `crash` directive payload:

```erlang
6> beamq_store:add_job(#{task => "flaky_third_party_api", action => crash}).
4

```

*Observe how the worker catches the error, drops the slot, and safely parks the job in `retry_delay` status while an asynchronous alarm counts down.*

## Project Structure

```text
beamq/
├── src/
│   ├── beamq_app.erl         # Application behavior and startup initialization
│   ├── beamq_sup.erl         # Supervision tree strategy (One_For_All protection)
│   ├── beamq_store.erl       # Thread-safe job storage engine and atomic locking (ETS)
│   ├── beamq_scheduler.erl   # Concurrency-capped governor managing worker pools via process monitors
│   └── beamq_worker.erl      # Isolated execution environments running background calculations
└── rebar.config

```

## State Machine Transition Matrix

```text
                [ Job Produced ]
                       │
                       ▼
                 ┌───────────┐
                 │   ready   │
                 └─────┬─────┘
                       │ (Scheduler Checkout)
                       ▼
                 ┌───────────┐
                 │  running  │
                 └─┬───────┬─┘
                   │       │
   Worker Success  │       │  Worker Crashes (Attempts < Max)
                   ▼       ▼
        ┌───────────┐     ┌───────────────┐
        │ completed │     │  retry_delay  │
        └───────────┘     └───────┬───────┘
                                  │
                                  │ (Async Alarm Trigger)
                                  ▼
                            [ Back to ready ]

```