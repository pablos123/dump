-module(client).
-include("/1TBDisk/Files/aLCC/Sistemas Operativos I/Erlang/tp/structs.hrl").
-export([start/1, commands/2]).

start(Port)->
	case io:get_line("Ingrese CON -nombre para conectarse al servidor de TaTeTi: ") of
		"CON " ++ Data ->
			WordList = string:lexemes(Data, "\n"),
			{ok, Socket} = gen_tcp:connect("localhost" % "localhost" = 127.0.0.1 o 150.0.10.2
										   , Port
										   , [ binary
											 , {packet, 0}
											 , {active,false}]),
			%esperar a que el server me de el okey del connect
			{ok, ServerConfirmation} = gen_tcp:recv(Socket, 0),
			io:format("~p", [binary_to_term(ServerConfirmation)]),
			
			try hd(WordList) of
				_ -> 
					gen_tcp:send(Socket, term_to_binary(hd(WordList))),
					{ok, Answer} = gen_tcp:recv(Socket, 0),
					case binary_to_term(Answer) of
						error ->
							io:format("El nombre ya esta en uso, ingrese otro.~n"),
							start(Port);
						_ ->
							ok
					end
			catch
				_:_ -> 
					io:format("Debe ingresar un nombre válido.~n"),
					start(Port)
			end,
			%aca spawneamos dos procesos uno para escuchar todo el tiempo y otro para poder recibir sin problemas cuando haya que recibir muchas cosas
			commands(Socket, 1);
	
		{error, _ErrorDescription} -> 
			io:format("Error de lectura~n");
		
		Other ->
			case Other of
				"CON\n" ->
					io:format("Debe ingresar un nombre válido.~n");
				_ ->
					io:format("Comando inválido. ~n")
			end
	end,
	start(Port).
	

commands(Socket, CmdCounter) ->
	%CACA A MODULARIXAR XD
	case io:get_line("Ingrese algun comando (help para ver la lista disponible): ") of
	"LSG\n" ->
		gen_tcp:send(Socket, term_to_binary({lsg, CmdCounter})),
		{ok, Answer} = gen_tcp:recv(Socket, 0),
		%desde el servidor le decimos a todos los servidores que impriman la lista de juegos en la terminal de este cliente
		io:format("La lista de juegos disponibles es: ~p ~n", [binary_to_term(Answer)]),
		commands(Socket, CmdCounter + 1);
	
	"NEW\n" ->
		gen_tcp:send(Socket, term_to_binary({new, CmdCounter})),
		{ok, Answer} = gen_tcp:recv(Socket, 0),
		io:format("~p~n", [binary_to_term(Answer)]),
		commands(Socket, CmdCounter + 1);
		
	"ACC " ++ Cacc -> %"1 'pop@os'"
		Lista = string:lexemes(Cacc, " "), % --> ["1", "'pop-os'\n"] connect_node('server1@pop-os')
		Numero = list_to_integer(hd(Lista)),
		%io:format("nodo string: ~p", [hd(string:lexemes(tl(Lista), "\n"))]), aca esta como string pero despues al convertirlo le agrega los '' xd
		Node = list_to_atom(hd(string:lexemes(tl(Lista), "\n"))),
		%Node = string:replace(Nodexd, "\"", "'"),
		io:format("~p~p", [Numero, Node]),
		gen_tcp:send(Socket, term_to_binary({acc, CmdCounter, {Numero, Node}})),
		{ok, Answer} = gen_tcp:recv(Socket, 0),
		io:format("~p~n", [binary_to_term(Answer)]),
		commands(Socket, CmdCounter + 1);
	
	"PLA " ++ Cacc ->	% "PLA juegoid rowNo colNo" NOICE :)
		Lista = string:lexemes(Cacc, " "), % --> ["numerojuegoid", "server1@pop-os", "1", "1"]
		ListWithoutNumber = tl(Lista),
		Numero = list_to_integer(hd(Lista)),
		ListWithoutNode = tl(ListWithoutNumber),
		Node = list_to_atom(hd(ListWithoutNumber)),
		Row = list_to_integer(hd(ListWithoutNode)),
		WithoutSlashN = string:lexemes(tl(ListWithoutNode), "\n"), 
		Col = list_to_integer(hd(WithoutSlashN)),
		gen_tcp:send(Socket, term_to_binary({pla, CmdCounter, {Numero, Node}, Row, Col})),
		{ok, Answer} = gen_tcp:recv(Socket, 0),
		io:format("~p~n", [binary_to_term(Answer)]),
		commands(Socket, CmdCounter + 1);
	
	"OBS " ++ Cacc ->
		Lista = string:lexemes(Cacc, " "), % --> ["1", "'pop-os'\n"] connect_node('server1@pop-os')
		Numero = list_to_integer(hd(Lista)),
		%io:format("nodo string: ~p", [hd(string:lexemes(tl(Lista), "\n"))]), aca esta como string pero despues al convertirlo le agrega los '' xd
		Node = list_to_atom(hd(string:lexemes(tl(Lista), "\n"))),
		%Node = string:replace(Nodexd, "\"", "'"),
		io:format("~p~p", [Numero, Node]),
		gen_tcp:send(Socket, term_to_binary({obs, CmdCounter, {Numero, Node}})),
		{ok, Answer} = gen_tcp:recv(Socket, 0),
		io:format("~p~n", [binary_to_term(Answer)]),
		commands(Socket, CmdCounter + 1);
	
	"LEA " ++ Cacc ->
		Lista = string:lexemes(Cacc, " "), % --> ["1", "'pop-os'\n"] connect_node('server1@pop-os')
		Numero = list_to_integer(hd(Lista)),
		%io:format("nodo string: ~p", [hd(string:lexemes(tl(Lista), "\n"))]), aca esta como string pero despues al convertirlo le agrega los '' xd
		Node = list_to_atom(hd(string:lexemes(tl(Lista), "\n"))),
		%Node = string:replace(Nodexd, "\"", "'"),
		io:format("~p~p", [Numero, Node]),
		gen_tcp:send(Socket, term_to_binary({lea, CmdCounter, {Numero, Node}})),
		{ok, Answer} = gen_tcp:recv(Socket, 0),
		io:format("~p~n", [binary_to_term(Answer)]),
		commands(Socket, CmdCounter + 1);

	"BYE\n" ->
		gen_tcp:send(Socket, term_to_binary({bye, CmdCounter})),
		{ok, Answer} = gen_tcp:recv(Socket, 0),
		io:format("~p~n", [Answer]),
		commands(Socket, CmdCounter + 1);

	"CON\n" ->
		gen_tcp:send(Socket, term_to_binary({con, CmdCounter})),
		{ok, Answer} = gen_tcp:recv(Socket, 0),
		io:format("~p~n", [binary_to_term(Answer)]),
		commands(Socket, CmdCounter + 1);
	
	"help\n" ->
		gen_tcp:send(Socket, term_to_binary({help, CmdCounter})),
		{ok, Answer} = gen_tcp:recv(Socket, 0),
		io:format("~p~n", [Answer]),
		commands(Socket, CmdCounter + 1);
		

	{error, _ErrorDescription} -> 
		io:format("Error de lectura~n"),
		commands(Socket, CmdCounter);
		
	_ -> 
		io:format("Comando inválido.~n"),
		commands(Socket, CmdCounter)
	end.
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	 
			
