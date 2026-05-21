-module(beamq_store).
-behaviour(gen_server).

-export([start_link/0, add_job/1, get_job/0, ack_job/1, mark_running/1, fail_job/2]).
-export([init/1, handle_call/3, handle_cast/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ets:new(jobs, [named_table, public, set]),
    {ok, #{counter => 0}}.

add_job(Payload) ->
    gen_server:call(?MODULE, {add, Payload}).

get_job() ->
    gen_server:call(?MODULE, get).

ack_job(Id) ->
    gen_server:call(?MODULE, {ack, Id}).

mark_running(Id) ->
    gen_server:call(?MODULE, {mark_running, Id}).

fail_job(Id, Error) ->
    gen_server:call(?MODULE, {fail, Id, Error}).

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

handle_call(get, _From, State) ->
    Jobs = ets:tab2list(jobs),
    Result = case lists:filter(
        fun({_, J}) -> maps:get(status, J) =:= ready end,
        Jobs
    ) of
        []            -> none;
        [{Id, J} | _] -> {Id, J}
    end,
    {reply, Result, State};

handle_call({ack, Id}, _From, State) ->
    case ets:lookup(jobs, Id) of
        [{Id, Job}] ->
            ets:insert(jobs, {Id, Job#{status => completed}});
        _ ->
            ok
    end,
    {reply, ok, State};

handle_call({mark_running, Id}, _From, State) ->
    case ets:lookup(jobs, Id) of
        [{Id, Job}] ->
            Updated = Job#{
                status   => running,
                attempts => maps:get(attempts, Job) + 1
            },
            ets:insert(jobs, {Id, Updated});
        _ ->
            ok
    end,
    {reply, ok, State};

handle_call({fail, Id, Reason}, _From, State) ->
    case ets:lookup(jobs, Id) of
        [{Id, Job}] ->
            Attempts    = maps:get(attempts, Job),
            MaxAttempts = maps:get(max_attempts, Job),
            NewStatus   = case Attempts >= MaxAttempts of
                true  -> failed;
                false -> ready
            end,
            ets:insert(jobs, {Id, Job#{status => NewStatus, error => Reason}});
        _ ->
            ok
    end,
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.