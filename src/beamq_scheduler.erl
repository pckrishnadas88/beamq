-module(beamq_scheduler).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    timer:send_interval(1000, tick),
    {ok, #{}}.

handle_call(_Req, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(tick, State) ->
    case beamq_store:get_job() of
        none ->
            ok;

        {Id, Job} ->
            beamq_store:mark_running(Id),
            spawn(fun() -> beamq_worker:run(Id, Job) end)
    end,
    {noreply, State};

handle_info(_Other, State) ->
    {noreply, State}.
