-module(beamq_worker).
-export([run/2]).

run(Id, Job) ->
    try
        Payload = maps:get(payload, Job),
        io:format("[Worker ~p] Executing Job ~p: ~p~n", [self(), Id, Payload]),

        timer:sleep(2000),

        case maps:get(action, Payload, ok) of
            crash -> error(intentional_worker_crash);
            ok    -> ok
        end, %% <-- Fixed here!

        beamq_store:ack_job(Id),
        io:format("[Worker ~p] Finished Job ~p successfully.~n", [self(), Id])
    catch
        Class:Reason ->
            io:format("[Worker ~p] FAILED Job ~p -> ~p:~p~n", [self(), Id, Class, Reason]),
            beamq_store:fail_job(Id, {Class, Reason})
    end.