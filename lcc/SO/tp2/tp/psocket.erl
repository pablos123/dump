-module(psocket).
-include("/1TBDisk/Files/aLCC/Sistemas Operativos I/Erlang/tp/structs.hrl").
-include("/1TBDisk/Files/aLCC/Sistemas Operativos I/Erlang/tp/timeConstants.hrl").
-export([psocket/3, pcommand/2, lsg/1, game/1, getGames/2]).

psocket(Socket, Username, DispatcherPid) -> %Username ahora es un record
	case gen_tcp:recv(Socket, 0, ?TIMEOUT) of %otro time out que ejecuta el receive
		{error, timeout} -> %me fijo si hay una respuesta del pcommand
			receive
				{ok, Results} ->	%recibe respuesta del pcommand o update del server por algun cambio
					gen_tcp:send(Socket, term_to_binary({ok, Results})),
					psocket(Socket, Username, DispatcherPid)
			after ?TIMEOUT ->
					psocket(Socket, Username, DispatcherPid)
			end;
		{error, _Reason} ->
			io:format("El cliente ~p cerró la conexión~n",[Username]), %entra aca, esto lo hago para que sea lomismo que cerrar la terminal
			% lsg(bye) --> borrar juegos en los que participe, si es que hay
			% game(bye)
			DispatcherPid ! {bye, Username#username.name},
			gen_tcp:close(Socket);
		{ok, Package} ->	%recibe un comando
			Command = binary_to_term(Package),
			global:send({pbalance, node(self())}, {nodepls, self()}),  %EXCEPCIONESSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
			receive
				{ok, Answer} ->	%recibe el nodo con  menor carga
					spawn(Answer, psocket, pcommand, [Command, Username]),
					psocket(Socket, Username, DispatcherPid)
			end
	end.


pcommand(Command, Username) ->
	case Command of
		{lsg, CmdCounter} ->
			%le envia a su lsg que se encargue de recolectar la lista de juegos de los otros lsg. este lsg le devuelve la lista
			%al pcomando y este se la manda al psocket
			global:send({lsg, node(self())}, {lsg, collectGames, self()}),
			io:format("le mando a lsg que colecte ~n"),
			receive
				{ok, GameList} ->
					io:format("pcomand - enviacion de la listadejuegos: ~p ~n",[GameList]),
					global:send({psocket, Username}, {ok, {ok, lsg, CmdCounter, GameList}});
				{error, _Reason} ->
					global:send({psocket, Username}, {ok, {error, lsg, CmdCounter, "Error en el muestreo de la lista"}}) %TODO
			end;
		{new, CmdCounter} ->
			%lsg: { {{idInternoServer, nodoServer} => record}} --- registrado globalmente asi: {game, {idInterno, nodoServer}}
			%modularizar esto en un newBoard() %aca le tenemos que decir que haga la primera jugada
			NewBoard = mapInitializer(maps:new(), 1),
			NewGame = #game{gameinternalid = none, leader = Username, enemy = missing, observers = [Username], board = NewBoard, isplayable = 1},
			global:send({lsg, node(self())}, {store, NewGame, self()}),
			receive
				{ok, GameWithId} ->
					global:send({psocket, Username}, {ok, {ok, new, CmdCounter, "Se creo el juego GamePid"}}),
					GamePid = spawn(?MODULE, game, [GameWithId]),
					global:register_name({game, {GameWithId#game.gameinternalid, node(self())}}, GamePid);
				{error, _Reason} ->
					global:send({psocket, Username}, {ok, {error, new, CmdCounter, "No se creo el juego GamePid"}})
			end;

		{acc, CmdCounter, GameId} -> %acc cmdid {1,server1@pop-os} GameId --> '{4,'server@pop-os}'
			%acepta el juego identificado como juego id.
			io:format("Entre aca a acc en psocket~n"),
			global:register_name({pcommand, node(self()), self()}, self()), %PODEMOS CHEQUEAR QUE ONDA EL UNREGISTER NAME PARA ESTO
			global:send({game, GameId}, {acc, enemy, Username, node(self()), self()}),  
			receive
				{ok, enemySaved} ->
					global:send({psocket, Username}, {ok, {ok, acc, CmdCounter, "Se acepto el juego Gameid"}});
				{error, _Reason} ->
					global:send({psocket, Username}, {ok, {ok, acc, CmdCounter, "Error en la aceptacion"}})
			end;
		{pla, CmdCounter, GameId, Row, Col} ->
			%realiza una jugada en el juego identificado por juego id
			io:format("Se viene una nueva jugada~n"),
			global:register_name({pcommand, node(self()), self()}, self()), %el game puede estar en cualquier nodo
			global:send({game, GameId}, {pla, Row, Col, Username, node(self()), self()}),
			receive
				{ok, playSaved} ->
					global:send({psocket, Username}, {ok, {ok, pla, CmdCounter, "Se hizo la jugada en el juego Gameid"}});
				{error, _Reason} ->
					global:send({psocket, Username}, {ok, {error, pla, CmdCounter, "Hubo un error en la jugada"}})
			end;
		{obs, CmdCounter, GameId} ->
			io:format("Quiero observar el juego~n"),
			global:register_name({pcommand, node(self()), self()}, self()),
			global:send({game, GameId}, {obs, Username, node(self()), self()}),
			receive
				{ok, obs, Board} ->
					global:send({psocket, Username}, {ok, {ok, obs, CmdCounter, "Listo, ahora estas observando!~nEl estado actual es:~n", Board}});
				{error, _Reason} ->
					global:send({psocket, Username}, {ok, {error, obs, CmdCounter, "Hubo un error tratando de observar"}})
			end;
			%el game puede estar en cualquier nodo

			%se le empieza a mandar _updates_ con el estado del juego. Al ppio le manda el estado actual.
		{lea, CmdCounter, GameId} ->
			io:format("No quiero observar mas el juego~n"),
			global:register_name({pcommand, node(self()), self()}, self()),
			global:send({game, GameId}, {lea, Username, node(self()), self()}),
			receive
				{ok, lea} ->
					global:send({psocket, Username}, {ok, {ok, obs, CmdCounter, "Listo, ya no observas mas"}});
				{error, _Reason} ->
					global:send({psocket, Username}, {ok, {error, obs, CmdCounter, "Hubo un error tratando de dejar de observar"}})
			end;
		{bye, _CmdCounter} ->
			%global:send({psocket, Username}, {error, nosvemos});
			%termina la conexion. abandona todos los juegos en los que participe.
			ok;
		{con, CmdCounter} ->
			global:send({psocket, Username}, {ok, {error, con, CmdCounter, "Ya estas conectado!"}});
        {error, closed} ->
            io:format("El cliente cerró la conexión~n") 
    end.

lsg(Map) ->
	receive
		{store, Game, PcommandPid} ->
			InternalId = maps:size(Map) + 1,
			CurrentNode = node(self()),
			NewGame = Game#game{gameinternalid=InternalId},
			NewMap = maps:put({InternalId, CurrentNode}, NewGame, Map),
			PcommandPid ! {ok, NewGame},
			io:format("Gamemap al agregar el juego: ~p", [NewMap]),
			lsg(NewMap);
		{lsg, collectGames, PCommandPid} ->
			io:format("Estoy empezando a recolectar juegos...~n"),
			%mensajea a sus hermanitxs, recibe sus mapas, agrega el suyo y se lo manda al pcommand
			GameList = getGames(nodes(), Map),
			PCommandPid ! {ok, GameList},
			io:format("ya Game#game.enemyle mande la lista al pcommand ~n"),
			lsg(Map);
		{lsg, giveGames, OriginLsgNode} ->  %me llega la peticion de otro lsg para darle mis jueguitos
			global:send({lsg, OriginLsgNode}, {ok, Map}),
			lsg(Map);
		{update, Game} ->
			UpdatedMap = maps:update({Game#game.gameinternalid, node(self())}, Game, Map),
			lsg(UpdatedMap)
	end.

game(Game) ->
	receive
		{acc, enemy, EnemyName, PcommandNode, PcommandPid} ->	%acc esta escrito aca
		case (EnemyName == Game#game.leader) or (Game#game.isplayable == 0) of
			false ->
				UpdatedGame = Game#game{enemy = EnemyName, isplayable = 0, observers = Game#game.observers ++ [EnemyName]},% != missing --> no necesario pq arranca el host
				global:send({pcommand, PcommandNode, PcommandPid}, {ok, enemySaved}), %aca hay que poner isplayable en 0 y despues fijarme antes en acc si no esta en 0
				global:send({lsg, node(self())}, {update, UpdatedGame}),	%actualizar lsg
				game(UpdatedGame);
			true ->
				global:send({pcommand, PcommandNode, PcommandPid}, {error, errorInAccepting}),
				game(Game)
		end;
		{pla, RowNumber, ColNumber, Username, PcommandNode, PcommandPid} ->	%jugadas ilegales: 0) juega sin haber aceptado el juego 1) no respeta turno 2) ocupa lugar ya ocupado 3) ocupa lugar afuera de la matriz _(no encuentra la key en el mapa)_
			case maps:get({RowNumber, ColNumber},Game#game.board) of
				{badkey, _Key} ->
					global:send({pcommand, PcommandNode, PcommandPid}, {error, play}),
					game(Game); %bad coords
				Value ->
					case (Game#game.previousPlayerPlay == Username) or (Value /= "m") of	%3:) %aca hagamos excepciones anidando case y ya esta jajaja saludos^
						false ->
							Leader = Game#game.leader,
							Enemy = Game#game.enemy,
							CurrentBoard = Game#game.board,
							case Username of
								Leader ->
									io:format("Juega el lider fila: ~p  columna: ~p~n", [RowNumber, ColNumber]),
									UpdatedBoard = maps:update({RowNumber, ColNumber}, "X", CurrentBoard),
									UpdatedGame = Game#game{board = UpdatedBoard, previousPlayerPlay = Username},
									global:send({pcommand, PcommandNode, PcommandPid}, {ok, playSaved}),
									io:format("Juego actualizado ~p", [UpdatedGame]),
									sendUpdates(Username, RowNumber, ColNumber, UpdatedGame#game.board, UpdatedGame#game.observers),
									game(UpdatedGame);
								Enemy ->
									io:format("Juega el enemigo ~n"),
									UpdatedBoard = maps:update({RowNumber, ColNumber}, "O", CurrentBoard),
									UpdatedGame = Game#game{board = UpdatedBoard, previousPlayerPlay = Username},
									global:send({pcommand, PcommandNode, PcommandPid}, {ok, playSaved}),
									io:format("Juego actualizado ~p", [UpdatedGame]),
									sendUpdates(Username, RowNumber, ColNumber, UpdatedGame#game.board, UpdatedGame#game.observers),
									game(UpdatedGame);
								_ ->
									global:send({pcommand, PcommandNode, PcommandPid}, {error, play}),	%metido
									game(Game)
							end;
						true ->
							global:send({pcommand, PcommandNode, PcommandPid}, {error, play}),	%no respeta turno
							game(Game)
					end
			end;
		{obs, Username, PcommandNode, PcommandPid} ->
			NewGame = Game#game{observers = Game#game.observers ++ [Username]},
			global:send({lsg, node(self())}, {update, NewGame}),	%actualizar lsg
			global:send({pcommand, PcommandNode, PcommandPid}, {ok, obs, Game#game.board}),
			game(NewGame);
		{lea, Username, PcommandNode, PcommandPid} ->
			NewObservers = removeObservers(Game#game.observers, Username),
			NewGame = Game#game{observers = NewObservers},
			global:send({lsg, node(self())}, {update, NewGame}),	%actualizar lsg
			global:send({pcommand, PcommandNode, PcommandPid}, {ok, lea}),
			game(NewGame)
	end. 

removeObservers([], _Username) ->
	[];
removeObservers([Hd | Tl], Username) ->
	case Hd of
		Username ->
			removeObservers(Tl, Username);
		_ -> 
			[Hd] ++ removeObservers(Tl, Username)
	end.

sendUpdates(_Username, _RowNumber, _ColNumber, _Board, []) ->
	ok;
sendUpdates(Username, RowNumber, ColNumber, Board, [Hd | Tl]) ->
	global:send({psocket, Hd}, {ok, {RowNumber, ColNumber, Board}}),
	sendUpdates(Username, RowNumber, ColNumber, Board, Tl).

mapInitializer(Map, 4) ->
	Map;
mapInitializer(Map, RowN) ->
	NewMap = columnInitializer(Map, RowN, 1),
	mapInitializer(NewMap, RowN + 1).
	
columnInitializer(Map, _RowN, 4) ->
	Map;
columnInitializer(Map, RowN, ColN) ->
	NewMap = maps:put({RowN, ColN}, "m", Map),
	columnInitializer(NewMap,RowN, ColN + 1).
	


% 1 2
% Row = list_to_atom("row" ++ "1")
% (Board#board.Row)#row.list_to_atom("col" ++ "2")

%Version1
% getGames([], Map) ->
% 	Map;
	
% getGames([Elem | Tl], Map) ->
% 	%io:format("~p", [Elem]),
% 	case Elem of
% 		{lsg, _NodeName} ->
% 			global:send(Elem, {lsg, giveGames, node(self())}),
% 			receive
% 				{ok, OtherServerMap} ->
% 					NewMap = maps:merge(Map, OtherServerMap),
% 					getGames(Tl, NewMap)
% 			end;
% 		_ ->
% 			getGames(Tl, Map)
% 	end.

%Version2
getGames([], Map) ->
	io:format("entro a getgames nodes vacia ~n"),
	Map;
	
getGames([Node | Tl], Map) ->
	%io:format("~p", [Elem]),
	global:send({lsg, Node}, {lsg, giveGames, node(self())}),
	receive
		{ok, OtherServerMap} ->
			NewMap = maps:merge(Map, OtherServerMap),
			getGames(Tl, NewMap)
	end.