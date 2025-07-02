%Definimos la estructura para el nombre del usuario.
-record(username, {name, nodename}).
-record(tasks, {nodename, taskcount}).
-record(game, {gameinternalid, leader, enemy, observers, board, previousPlayerPlay, isplayable}).

%Definimos la estructura para los puertos.
-record(port, {number, isactive}).
