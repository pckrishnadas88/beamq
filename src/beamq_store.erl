-module(beamq_store).
-behaviour(gen_server).

%% API
-export([start_link/0, add_job/1, get_and_lock_job/0, ack_job/1, fail_job/2]).
%% Callbacks
-export([init/1, handle_call/3, handle_cast/2, terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% ordered_set keeps our integer IDs sequential (FIFO)
    ets:new(jobs, [named_table, public, ordered_set]),
    {ok, #{counter => 0}}.

add_job(Payload) ->
    Id = gen_server:call(?MODULE, {add, Payload}),
    beamq_scheduler:notify_new_job(),
    Id.

get_and_lock_job() ->
    gen_server:call(?MODULE, get_and_lock).

ack_job(Id) ->
    gen_server:call(?MODULE, {ack, Id}).

fail_job(Id, Error) ->
    gen_server:call(?MODULE, {fail, Id, Error}).

%% --- GenServer Callbacks ---

handle_call({add, Payload}, _From, State) ->
    Id = maps:get(counter, State) + 1,
    Job = #{
        id           => Id,
        payload      => Payload,
        status       => ready,
        attempts     => 0,
        max_attempts => 3,
        error        => nil
    },
    ets:insert(jobs, {Id, Job}),
    {reply, Id, State#{counter => Id}};

handle_call(get_and_lock, _From, State) ->
    %% Match Spec: Find the first record where status is 'ready'
    MatchSpec = [{{'$1', #{status => ready}}, [], ['$_']}],
    Result = case ets:select(jobs, MatchSpec, 1) of
        {[{Id, Job}], _Continuation} ->
            Updated = Job#{
                status   => running,
                attempts => maps:get(attempts, Job) + 1
            },
            ets:insert(jobs, {Id, Updated}),
            {Id, Updated};
        '$end_of_table' ->
            none
    end,
    {reply, Result, State};

handle_call({ack, Id}, _From, State) ->
    %% Phase 2 explicit transition: ready -> running -> completed
    case ets:lookup(jobs, Id) of
        [{Id, Job}] ->
            ets:insert(jobs, {Id, Job#{status => completed}});
        _ -> ok
    end,
    {reply, ok, State};

handle_call({fail, Id, Reason}, _From, State) ->
    %% Phase 2 explicit transition: ready -> running -> failed (or back to ready)
    case ets:lookup(jobs, Id) of
        [{Id, Job}] ->
            Attempts = maps:get(attempts, Job),
            MaxAttempts = maps:get(max_attempts, Job),
            NewStatus = case Attempts >= MaxAttempts of
                true  -> failed;  %% No retries left
                false -> ready    %% Available to be picked up again
            end,
            ets:insert(jobs, {Id, Job#{status => NewStatus, error => Reason}});
        _ -> ok
    end,
    {reply, ok, State}.

handle_cast(_Msg, State)          -> {noreply, State}.
terminate(_Reason, _State)        -> ok.
code_change(_OldVsn, State, _Ext) -> {ok, State}.