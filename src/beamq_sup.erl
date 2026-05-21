-module(beamq_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
	Children = [
		{beamq_store,
			{beamq_store, start_link, []},
            permanent, 5000, worker, [beamq_store]},

        {beamq_scheduler,
            {beamq_scheduler, start_link, []},
            permanent, 5000, worker, [beamq_scheduler]}
    ],

    {ok, {{one_for_all, 5, 10}, Children}}.
