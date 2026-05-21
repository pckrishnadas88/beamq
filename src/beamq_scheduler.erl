-module(beamq_scheduler).
-behaviour(gen_server).

-export([start_link/0, notify_new_job/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(MAX_CONCURRENT_JOBS, 3). %% Phase 3 Concurrency Limit

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

notify_new_job() ->
    gen_server:cast(?MODULE, check_queue).

init([]) ->
    self() ! check_queue,
    {ok, #{running_workers => 0}}.

handle_call(_Req, _From, State) ->
    {reply, ok, State}.

handle_cast(check_queue, State) ->
    {noreply, maybe_start_workers(State)};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(check_queue, State) ->
    {noreply, maybe_start_workers(State)};

%% Automatically handles explicit process monitoring and cleanup
handle_info({'DOWN', _Ref, process, _Pid, _Reason}, State) ->
    CurrentCount = maps:get(running_workers, State),
    UpdatedState = State#{running_workers => max(0, CurrentCount - 1)},
    self() ! check_queue, %% Check if jobs piled up while workers were busy
    {noreply, UpdatedState};

handle_info(_Other, State) ->
    {noreply, State}.

terminate(_Reason, _State) -> ok.

%% --- Internal Processing Loop ---

maybe_start_workers(#{running_workers := Active} = State) when Active >= ?MAX_CONCURRENT_JOBS ->
    State; %% Max capacity hit. Hold back.
maybe_start_workers(#{running_workers := Active} = State) ->
    case beamq_store:get_and_lock_job() of
        none -> 
            State; %% Queue is empty
        {Id, Job} ->
            %% Spawn isolated worker process and monitor its lifecycle
            spawn_monitor(fun() -> beamq_worker:run(Id, Job) end),
            maybe_start_workers(State#{running_workers => Active + 1})
    end.