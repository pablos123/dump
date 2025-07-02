-module(server).
-include("/1TBDisk/Files/aLCC/Sistemas Operativos I/Erlang/tp/timeConstants.hrl").
-include("/1TBDisk/Files/aLCC/Sistemas Operativos I/Erlang/tp/structs.hrl").
-import(dispatcher, [dispatcher/2]).
-export([start/1, pbalance/2, pstat/0, sendTasksLoad/1]).

start(Port) ->
    {ok, LSocket} = gen_tcp:listen(Port, [binary, {packet, 0}, {active, false}]), %lo dejamos con false porque vamos a usar gen_tcp:recv
    io:format("Tasks activas: ~p~n", [erlang:statistics(total_active_tasks)]),
    
    PbalancePid = spawn(?MODULE, pbalance, [node(self()), erlang:statistics(total_active_tasks)]),
    global:register_name({pbalance, node(self())}, PbalancePid),
    LsgPid = spawn(psocket, lsg, [maps:new()]), 
    global:register_name({lsg, node(self())}, LsgPid),
    spawn(?MODULE, pstat, []),
    dispatcher:dispatcher(LSocket, maps:new()).


pbalance(LessTasksNode, LessTasksCount) ->
	%io:format("pbalance pid~p~n",[self()]), 
	ConnectedNodes = nodes() ++ [node(self())], %tambien comparamos consigo mismo
	%flag exit true %hay que hacer el linkkkkkkkkkkkkk
	receive
		%{error, Jaja} ->
		%se desconecto un nodo
		{nodepls, Pid} ->
			Pid ! {ok, LessTasksNode},
			pbalance(LessTasksNode, LessTasksCount);
		{NodeName, TasksCount} ->
			IsConnected = lists:member(NodeName, ConnectedNodes),
			%io:format("~pless~ptasksnuevas~p", [IsConnected, LessTasksCount,TasksCount]),
			if
				IsConnected and (TasksCount =< LessTasksCount) ->
					%io:format("~p tareas en el momento del nodo ~p.~n", [TasksCount, NodeName]),
					pbalance(NodeName, TasksCount);   
				true ->
					pbalance(LessTasksNode, LessTasksCount)
			end
	end.

pstat() ->
	sendTasksLoad(global:registered_names()),
	timer:sleep(1000),
	pstat().

sendTasksLoad([]) ->
	ok;
	
sendTasksLoad([Elem | Tl]) ->
	%io:format("~p", [Elem]),
	case Elem of
		{pbalance, _NodeName} ->
			global:send(Elem, {node(self()), erlang:statistics(total_active_tasks)}),
			sendTasksLoad(Tl);
		_ ->
			sendTasksLoad(Tl)
	end.
	
	
	
	
	
	
