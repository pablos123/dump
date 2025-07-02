-module(dispatcher).
-include("/1TBDisk/Files/aLCC/Sistemas Operativos I/Erlang/tp/structs.hrl").
-import(psocket, [psocket/1]).
-include("/1TBDisk/Files/aLCC/Sistemas Operativos I/Erlang/tp/timeConstants.hrl").
-export([dispatcher/2]).

dispatcher(LSocket, Map) ->
	%io:format("Dispatcher pid~p~n", [self()]),
    case gen_tcp:accept(LSocket, ?TIMEOUT) of
		{error, timeout} ->
			%io:format("hoal como estasssss"),
			receive
				{bye, Username} ->
					io:format("Removiendo ~p", [Username]),
					NewMap = maps:remove(Username, Map),
					dispatcher(LSocket, NewMap)
			after ?TIMEOUT ->
					dispatcher(LSocket, Map)
			end;

		{ok, Socket} ->
			io:format("Entro alguien, mandado mensaje {ok, connected}... ~n"),
			gen_tcp:send(Socket, term_to_binary({ok, connected})),
			case gen_tcp:recv(Socket, 0) of
				{error, _Closed} ->
					io:format("El cliente cerró la conexión~n");
				{ok, Username} ->
					io:format("Me llegó: ~p ~n", [binary_to_term(Username)]),
					NewName = binary_to_term(Username),
					NewUser = #username{name=NewName, nodename=node(self()), gamelist = maps:new()},
					case maps:find(NewUser#username.name, Map) of 
						{ok, _Value} ->
							gen_tcp:send(Socket, term_to_binary(error)),
							gen_tcp:close(Socket),
							dispatcher(LSocket, Map);
						error ->
							gen_tcp:send(Socket, term_to_binary(ok)),
							NewMap = maps:put(NewUser#username.name, NewUser, Map),
							PsocketPid = spawn(psocket, psocket, [Socket, NewUser, self()]),
							global:register_name({psocket, {NewUser#username.name, NewUser#username.nodename}}, PsocketPid),
							dispatcher(LSocket, NewMap)
					end
			end
	end.
