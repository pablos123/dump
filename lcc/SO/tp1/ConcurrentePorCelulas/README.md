El programa compila y crea un ejecutable en el directorio en el que se encuetra con el comando $make.
Si se desea limpiar el directorio sacando los archivos creados por $make se puede correr el comando $make clean, para borrarlos.

El comando que se ejecuta en el make es:
* -g -o simulador main.c Game.c Board.c GoLThreads.c GoLCoords.c -Wall -pedantic -pthread
#Tener en cuenta que -pedantic es muy exigente y puede imprimir warnings dependiendo de la versión del compilador.

#El programa acepta archivos de la forma descripta en el enunciado, de lo contrario imprime un mensaje de error.

En los archivos con extensión .h está comentada cada una de las funciones. Los comentarios sobre el código en los archivos con extensión .c 
estan en las funciones que no estaban en los templates presentados como referencia y que nos parecían más relevantes.

Se utilizaron casi todas las funciones con el tipado provisto en los templates, excepto:
* char board_get(board_t board, size_t col, size_t row);
que se cambió por:
* char board_get(board_t *board, size_t row, size_t col);
y
* int board_set(board_t board, size_t col, size_t row, char val);
que se cambió por:
* int board_set(board_t *board, size_t row, size_t col, char val);

para ser consistentes con las demás funciones declaradas.

Además, la función:
* int board_init(board_t *board, size_t col, size_t row);

se eliminó ya que no se utilizaba.

La devolución de algunas funciones enteras se utilizó para usar la función assert().






