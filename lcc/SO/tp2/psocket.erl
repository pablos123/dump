-module(psocket).
-include("/1TBDisk/Files/aLCC/Sistemas Operativos I/Erlang/tp/structs.hrl").
-include("/1TBDisk/Files/aLCC/Sistemas Operativos I/Erlang/tp/timeConstants.hrl").
-export([psocket/4, pcommand/3, lsg/1, game/1, getGames/2]).

psocket(Socket, Username, DispatcherPid, CmdCounter) -> %Username ahora es un record
	case gen_tcp:recv(Socket, 0, ?TIMEOUT) of %otro time out que ejecuta el receive
		{error, timeout} -> %me fijo si hay una respuesta del pcommand
			receive
				{ok, Results} ->	%recibe respuesta del pcommand o update del server por algun cambio
					gen_tcp:send(Socket, term_to_binary(Results)),
					psocket(Socket, Username, DispatcherPid, CmdCounter);
				bye ->
					io:format("El cliente ~p cerró la conexión~n", [Username]),
					DispatcherPid ! {bye, Username#username.name},
					gen_tcp:close(Socket)
			after ?TIMEOUT ->
					psocket(Socket, Username, DispatcherPid, CmdCounter)
			end;
		{error, _Reason} ->
			global:send({lsg, node(self())}, {lsg, collectGames, self()}),
			receive
				{ok, GameList} ->
					io:format("~p termina el mapa",[GameList]),
					removePlayer(maps:next(maps:iterator(GameList)), Username),
					DispatcherPid ! {bye, Username#username.name},
					gen_tcp:close(Socket);
				_ ->
					io:format("El cliente no salio correctamente~n"),
					DispatcherPid ! {bye, Username#username.name},
					gen_tcp:close(Socket)
			end;
		% {ok, received, CmdCounter} ->
			
		{ok, Package} ->	%recibe un comando
			Command = parser(binary_to_term(Package)),
			%io:format("~p~n", [Command]),
			case Command of 
				updateChecked -> 
					io:format("OK RECEIVED ~n"),
					psocket(Socket, Username, DispatcherPid, CmdCounter);
				_ ->
					global:send({pbalance, node(self())}, {nodepls, self()}),
					receive
						{ok, Answer} ->	%recibe el nodo con  menor carga
							spawn(Answer, psocket, pcommand, [Command, Username, CmdCounter]),
							psocket(Socket, Username, DispatcherPid, CmdCounter + 1)
					end
			end
	end.

parser(String) -> 
	ToList = string:lexemes(String, " "),
	case length(ToList) of
		1 -> %lsg, new, bye
			io:format("Entro al 1~n"),
			try list_to_atom(string:lowercase(hd(string:lexemes(String,"\n")))) of
				Command->
					Command
			catch
				_:_ -> " "
			end;
		2 ->
			case String == "OK  RECEIVED" of
				true ->
					updateChecked;
				false ->
					" "
			end;
		3 -> %acc, lea, obs ["acc", "1", "server@pop-os\n"]
			io:format("Entro al 3~n"),
			Command = list_to_atom(string:lowercase(hd(ToList))),
			try {list_to_integer(hd(tl(ToList))), list_to_atom(hd(string:lexemes(tl(tl(ToList)), "\n")))} of
				GameId ->
					{Command, GameId}
			catch
				_:_ -> " "
			end;
		4 -> %pla ["pla", "1", "server@pop-os", "bye\n"]
			Command = list_to_atom(string:lowercase(hd(ToList))),
			try {list_to_integer(hd(tl(ToList))), list_to_atom(hd(tl(tl(ToList))))} of
				GameId ->
					ByeAtom = list_to_atom(string:lowercase(hd(string:lexemes(tl(tl(tl(ToList))), "\n")))),
					{Command, GameId, ByeAtom}
			catch
				_:_ -> " "
			end;
		5 -> %pla ["pla", "1", "server@pop-os", "1", "1\n"]
			Command = list_to_atom(string:lowercase(hd(ToList))),
			try {list_to_integer(hd(tl(ToList))), list_to_atom(hd(tl(tl(ToList))))} of
				GameId ->
					try list_to_integer(hd((tl(tl(tl(ToList)))))) of
						Row ->
							try list_to_integer(hd(string:lexemes(tl(tl(tl(tl(ToList)))), "\n"))) of
								Col ->
									{Command, GameId, {Row, Col}}
							catch
								_:_ -> " "
							end
					catch
						_:_ -> " "
					end
			catch
				_:_ -> " "
			end;
		_ ->
			error
	end.

filterGamelist(none, String) ->
	String;
filterGamelist({{GameInternalId, GameNode}, Game, Tail}, String) ->
	NewString = String ++ "Juego Id: " ++ integer_to_list(GameInternalId) ++ " " ++ atom_to_list(GameNode) ++ "   Host: " ++ Game#game.leader#username.name ++ "   Enemy: " ++ Game#game.enemy#username.name ++ "|||",
	filterGamelist(maps:next(Tail), NewString).


pcommand(Command, Username, CmdCounter) -> %rta: {ok, stringParaelcliente} "OK/ERROR cmdid resultados"
	case Command of
		lsg ->
			%le envia a su lsg que se encargue de recolectar la lista de juegos de los otros lsg. este lsg le devuelve la lista
			%al pcomando y este se la manda al psocket
			global:send({lsg, node(self())}, {lsg, collectGames, self()}),
			receive
				{ok, GameList} ->
					ToShowGameList = filterGamelist(maps:next(maps:iterator(GameList)), ""),
					global:send({psocket, Username}, {ok, "OK  " ++ integer_to_list(CmdCounter) ++ "  La lista de juegos es:   " ++ ToShowGameList});
				{error, _Reason} ->
					global:send({psocket, Username}, {ok, "ERROR  " ++ integer_to_list(CmdCounter) ++ " Error en el muestreo de la lista"})
			end;
		new ->
			%lsg: { {{idInternoServer, nodoServer} => record}} --- registrado globalmente asi: {game, {idInterno, nodoServer}}
			%modularizar esto en un newBoard() %aca le tenemos que decir que haga la primera jugada
			NewBoard = mapInitializer(maps:new(), 1),
			NewGame = #game{gameinternalid = none, leader = Username, enemy = #username{name = "missing", nodename = missing}, observers = [Username], board = NewBoard, isplayable = 1},
			global:send({lsg, node(self())}, {store, NewGame, self()}),
			receive
				{ok, GameWithId} ->
					global:send({psocket, Username}, {ok, "OK  " ++ integer_to_list(CmdCounter) ++ "   Se creo el juego con Juego Id:  " ++ 
													integer_to_list(GameWithId#game.gameinternalid) ++ " " ++ atom_to_list(node(self()))}),
					GamePid = spawn(?MODULE, game, [GameWithId]),
					global:register_name({game, {GameWithId#game.gameinternalid, node(self())}}, GamePid);
				{error, _Reason} ->
					global:send({psocket, Username}, {ok, "ERROR  " ++ integer_to_list(CmdCounter) ++  " No se creo el juego GamePid"})
			end;

		{acc, GameId} -> %acc cmdid {1,server1@pop-os} GameId --> '{4,'server@pop-os}'
			%acepta el juego identificado como juego id.
			io:format("Entre aca a acc en psocket~n"),
			global:register_name({pcommand, node(self()), self()}, self()), %PODEMOS CHEQUEAR QUE ONDA EL UNREGISTER NAME PARA ESTO
			try global:send({game, GameId}, {acc, enemy, Username, node(self()), self()}) of
				_ -> 
					io:format("TODO ok en acc"),
					receive
						{ok, enemySaved} ->
							global:send({psocket, Username}, {ok, "OK " ++ integer_to_list(CmdCounter) ++  " Se acepto el juego."});
						{error, _Reason} ->
							global:send({psocket, Username}, {ok, "ERROR  " ++ integer_to_list(CmdCounter) ++ " Error en la aceptacion"})
					end
			catch
				_:_ ->
					io:format("NO ok en pla"),
					global:send({psocket, Username}, {ok, "ERROR  " ++ integer_to_list(CmdCounter) ++  " Juego Id no valido."})
		 	end;
		{pla, GameId, Play} ->
			%realiza una jugada en el juego identificado por juego id
			io:format("Se viene una nueva jugada~n"),
			global:register_name({pcommand, node(self()), self()}, self()), %el game puede estar en cualquier nodo
			try global:send({game, GameId}, {pla, Play, Username, node(self()), self()}) of
				_ -> 
					io:format("TODO ok en pla"),
					receive
						{ok, playSaved} ->
							global:send({psocket, Username}, {ok, "OK  " ++ integer_to_list(CmdCounter) ++  " Se hizo la jugada en el juego."});
						{error, _Reason} ->
							global:send({psocket, Username}, {ok, "ERROR  " ++ integer_to_list(CmdCounter) ++  " Hubo un error en la jugada."})
					end
			catch
				_:_ ->
					io:format("NO ok en pla"),
					global:send({psocket, Username}, {ok, "ERROR  " ++ integer_to_list(CmdCounter) ++ " Juego Id no valido"}) %Excepcionessssssssssssssssssssssssss, ya esta con esto???¿?¿¿?
		 	end;
		{obs, GameId} ->
			global:register_name({pcommand, node(self()), self()}, self()),
			try global:send({game, GameId}, {obs, Username, node(self()), self()}) of
				_ -> 
					receive
						{ok, obs, Board} ->
							global:send({psocket, Username}, {ok, "OK  " ++ integer_to_list(CmdCounter) ++  " Listo, ahora estas observando! El estado actual es: " ++ lists:flatten(io_lib:format("~p", [maps:to_list(Board)]))});
						{error, _Reason} ->
							global:send({psocket, Username}, {ok, "ERROR  " ++ integer_to_list(CmdCounter) ++ " Hubo un error tratando de observar"})
					end
			catch
				_:_ ->
					global:send({psocket, Username}, {ok, "ERROR  " ++ integer_to_list(CmdCounter) ++ " Juego Id no valido"}) %Excepcionessssssssssssssssssssssssss, ya esta con esto???¿?¿¿?
		 	end;
			%el game puede estar en cualquier nodo

			%se le empieza a mandar _updates_ con el estado del juego. Al ppio le manda el estado actual.
		{lea, GameId} ->
			global:register_name({pcommand, node(self()), self()}, self()),
			try global:send({game, GameId}, {lea, Username, node(self()), self()}) of
				_ -> 
					receive
						{ok, lea} ->
							global:send({psocket, Username}, {ok, "OK  " ++ integer_to_list(CmdCounter) ++ " Listo, ya no observas mas"});
						{error, _Reason} ->
							global:send({psocket, Username}, {ok, "ERROR  " ++  integer_to_list(CmdCounter) ++  " Hubo un error tratando de dejar de observar."})
					end
			catch
				_:_ ->
					global:send({psocket, Username}, {ok, "ERROR  " ++ integer_to_list(CmdCounter) ++  " Juego Id no valido"}) %Excepcionessssssssssssssssssssssssss, ya esta con esto???¿?¿¿?
		 	end;
		bye ->
			global:send({lsg, node(self())}, {lsg, collectGames, self()}),
			receive
				{ok, GameList} ->
					io:format("~p termina el mapa",[GameList]),
					removePlayer(maps:next(maps:iterator(GameList)), Username),
					global:send({psocket, Username}, {ok, "OK  " ++ integer_to_list(CmdCounter) ++ " Desconectandote... nos vemos!"}),
					global:send({psocket, Username}, bye);
				{error, _Reason} ->
					global:send({psocket, Username}, {ok, "ERROR  " ++ integer_to_list(CmdCounter) ++ " Error en tratando de salir."}) %TODO
			end;
        {error, _Reason} ->
            io:format("El cliente cerró la conexión~n");
		_ ->
			global:send({psocket, Username}, {ok, "ERROR  " ++ integer_to_list(CmdCounter) ++ " Comando invalido"})
    end.

			% pedimos la lista buscamos el username en la lista de juegos y lo sacamos si es leader o enemy terminamos el juego
			% y si no lo sacamos de la lista de observers
			%global:send({psocket, Username}, {error, nosvemos});
			%termina la conexion. abandona todos los juegos en los que participe.

removePlayer(none, _Player) ->
	ok;
removePlayer({{GameInternalId, GameNode}, Value, Tail} , Player) ->
	case (Player == Value#game.leader) or (Player == Value#game.enemy) of
		true ->
			global:send({lsg, GameNode}, {remove, GameInternalId}),
			gamesEnd(Player, Value#game.observers, GameInternalId, GameNode), %le decimos a todxs que se murio el jueguito
			global:send({game, {GameInternalId, GameNode}}, enemyLeaderGone), %matamos al juegordio
			removePlayer(maps:next(Tail), Player);
		false ->
			NewObserversList = removeObservers(Value#game.observers, Player),
			global:send({game, {GameInternalId, GameNode}}, {observersUpdate, NewObserversList}), %matamos al juegordio
			removePlayer(maps:next(Tail), Player)
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
			lsg(Map);
		{lsg, giveGames, OriginLsgNode} ->  %me llega la peticion de otro lsg para darle mis jueguitos
			global:send({lsg, OriginLsgNode}, {ok, Map}),
			lsg(Map);
		{update, Game} ->
			UpdatedMap = maps:update({Game#game.gameinternalid, node(self())}, Game, Map),
			lsg(UpdatedMap);
		{remove, GameId} ->
			UpdatedMap = maps:remove({GameId, node(self())}, Map),
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
		{pla, {RowNumber, ColNumber}, Username, PcommandNode, PcommandPid} ->	%jugadas ilegales: 0) juega sin haber aceptado el juego 1) no respeta turno 2) ocupa lugar ya ocupado 3) ocupa lugar afuera de la matriz _(no encuentra la key en el mapa)_
			try maps:get({RowNumber, ColNumber}, Game#game.board) of
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
									case checkWin(UpdatedBoard, "X") of
										true ->
											global:send({lsg, node(self())}, {remove, Game#game.gameinternalid}),
											sendUpdates(Username, RowNumber, ColNumber, UpdatedGame#game.board, UpdatedGame#game.observers, UpdatedGame#game.gameinternalid, node(self())),
											gamesEnd(Username, UpdatedGame#game.observers, UpdatedGame#game.gameinternalid, node(self())),
											exit(leaderWon);
										false ->
											sendUpdates(Username, RowNumber, ColNumber, UpdatedGame#game.board, UpdatedGame#game.observers, UpdatedGame#game.gameinternalid, node(self())),
											game(UpdatedGame)
									end;
								Enemy ->
									io:format("Juega el enemigo ~n"),
									UpdatedBoard = maps:update({RowNumber, ColNumber}, "O", CurrentBoard),
									UpdatedGame = Game#game{board = UpdatedBoard, previousPlayerPlay = Username},
									global:send({pcommand, PcommandNode, PcommandPid}, {ok, playSaved}),
									io:format("Juego actualizado ~p", [UpdatedGame]),
									case checkWin(UpdatedBoard, "O") of
										true ->
											global:send({lsg, node(self())}, {remove, Game#game.gameinternalid}),
											sendUpdates(Username, RowNumber, ColNumber, UpdatedGame#game.board, UpdatedGame#game.observers, UpdatedGame#game.gameinternalid, node(self())),
											exit(enemyWon);
										false ->
											sendUpdates(Username, RowNumber, ColNumber, UpdatedGame#game.board, UpdatedGame#game.observers, UpdatedGame#game.gameinternalid, node(self())),
											game(UpdatedGame)
									end;
								_ ->
									global:send({pcommand, PcommandNode, PcommandPid}, {error, play}),	%metido
									game(Game)
							end;
						true ->
							global:send({pcommand, PcommandNode, PcommandPid}, {error, play}),	%no respeta turno
							game(Game)
					end
				catch
					error:{badkey, _Key} ->
						global:send({pcommand, PcommandNode, PcommandPid}, {error, play}),
						game(Game) %bad coords
			end;
		{pla, bye, Username, PcommandNode, PcommandPid} -> %si no es su turno igualmente se puede ir 
			Leader = Game#game.leader,
			Enemy = Game#game.enemy,
			case (Username == Leader) or (Username == Enemy) of
				true  ->
					global:send({lsg, node(self())}, {remove, Game#game.gameinternalid}),

					gamesEnd(Username, Game#game.observers, Game#game.gameinternalid, node(self())),
					exit(gameTerminated);
				false ->
					global:send({pcommand, PcommandNode, PcommandPid}, {error, play})	%metido
			end;
			
		{obs, Username, PcommandNode, PcommandPid} ->
			case lists:member(Username, Game#game.observers) of
				true ->
					global:send({pcommand, PcommandNode, PcommandPid}, {error, obs}),
					game(Game);
				false ->
					NewGame = Game#game{observers = Game#game.observers ++ [Username]},
					global:send({lsg, node(self())}, {update, NewGame}),	%actualizar lsg
					global:send({pcommand, PcommandNode, PcommandPid}, {ok, obs, Game#game.board}),
					game(NewGame)
			end;
		{lea, Username, PcommandNode, PcommandPid} ->
			case lists:member(Username, Game#game.observers) of
				true ->
					NewObservers = removeObservers(Game#game.observers, Username),
					NewGame = Game#game{observers = NewObservers},
					global:send({lsg, node(self())}, {update, NewGame}),	%actualizar lsg
					global:send({pcommand, PcommandNode, PcommandPid}, {ok, lea}),
					game(NewGame);
					% global:send({pcommand, PcommandNode, PcommandPid}, {error, obs});
				false ->
					global:send({pcommand, PcommandNode, PcommandPid}, {error, lea}),
					game(Game)
			end;

		{observersUpdate, NewObservers} ->
			NewGame = Game#game{observers = NewObservers},
			global:send({lsg, node(self())}, {update, NewGame}),
			game(NewGame);
		enemyLeaderGone ->
			exit(leaderEnemyGone)
	end. 

checkWin(Board, Char) ->
	Elem1 = maps:get({1,1}, Board),
	Elem2 = maps:get({1,2}, Board),
	Elem3 = maps:get({1,3}, Board),
	Elem4 = maps:get({2,1}, Board),
	Elem5 = maps:get({2,2}, Board),
	Elem6 = maps:get({2,3}, Board),
	Elem7 = maps:get({3,1}, Board),
	Elem8 = maps:get({3,2}, Board),
	Elem9 = maps:get({3,3}, Board),
	((Elem1 == Elem2) and (Elem1 == Elem3) and (Elem1 == Char)) or
	((Elem4 == Elem5) and (Elem4 == Elem6) and (Elem4 == Char)) or
	((Elem7 == Elem8) and (Elem7 == Elem9) and (Elem7 == Char)) or
	((Elem1 == Elem4) and (Elem1 == Elem7) and (Elem1 == Char)) or
	((Elem2 == Elem5) and (Elem2 == Elem8) and (Elem2 == Char)) or
	((Elem3 == Elem6) and (Elem3 == Elem9) and (Elem3 == Char)) or
	((Elem3 == Elem5) and (Elem3 == Elem7) and (Elem3 == Char)) or
	((Elem1 == Elem5) and (Elem1 == Elem9) and (Elem1 == Char)).



removeObservers([], _Username) ->
	[];
removeObservers([Hd | Tl], Username) ->
	case Hd of
		Username ->
			removeObservers(Tl, Username);
		_ -> 
			[Hd] ++ removeObservers(Tl, Username)
	end.

gamesEnd(_Username, [], _GameId, _GameNode) ->
	ok;
gamesEnd(Username, [Hd | Tl], GameId, GameNode) ->
	global:send({psocket, Hd}, {ok, "UPD  El juego " ++ integer_to_list(GameId) ++  " " ++ atom_to_list(GameNode) ++ "termino!"}),
	gamesEnd(Username, Tl, GameId, GameNode).

sendUpdates(_Username, _RowNumber, _ColNumber, _Board, [], _GameId, _GameNode) ->
	ok;
sendUpdates(Username, RowNumber, ColNumber, Board, [Hd | Tl], GameId, GameNode) ->
	global:send({psocket, Hd}, {ok, "UPD  En el juego:  " ++ integer_to_list(GameId) ++  " " ++ atom_to_list(GameNode) ++
				" La jugada fue: " ++ integer_to_list(RowNumber) ++ " " ++ integer_to_list(ColNumber) ++ lists:flatten(io_lib:format("~p", [maps:to_list(Board)]))}),
	sendUpdates(Username, RowNumber, ColNumber, Board, Tl, GameId, GameNode).

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