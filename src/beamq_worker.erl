-module(beamq_worker).

-export([run/2]).

run(Id, Job) ->
    try
        Payload = maps:get(payload, Job),

        io:format("Processing job ~p: ~p~n", [Id, Payload]),

        timer:sleep(1000),

        beamq_store:ack_job(Id),

        io:format("Job ~p done~n", [Id])
    catch
        Class:Reason ->
            io:format("Job ~p failed: ~p:~p~n", [Id, Class, Reason]),
            beamq_store:fail_job(Id, {Class, Reason})
    end.
