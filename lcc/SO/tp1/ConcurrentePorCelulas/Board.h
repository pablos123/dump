#ifndef BOARD
#define BOARD

#include <stdio.h>
#include <stdlib.h>

/******************************************************************************/
/* Definición de la estructura de datos del tablero */

struct _board {
    char** cellStatus;
    long unsigned int rowCount;
    long unsigned int columnCount;
};

typedef struct _board board_t;
/******************************************************************************/

/* Funciones sobre el tablero */

/* Creación del tablero con un elemento por default*/
int board_init_def(board_t *board, size_t row, size_t col, char def);

/* Leer el tablero en una posición (col, row) */
char board_get(board_t *board, size_t row, size_t col);

/* Asignarle un valor 'val' a la posición (col, row) del tablero*/
int board_set(board_t *board, size_t row, size_t col, char val);

/* Leer de una lista de caracteres e interpretarla como un tablero */
int board_load(board_t *board, char *str);

/* Función para mostrar el tablero */
/* La función 'board_show' asume que hay espacio suficiente en 'res' para alojar el tablero.*/
void board_show(board_t board, char *res);

/* Destroys board */
void board_destroy(board_t *board);

/* Prints the given board_t*  */
void board_printer(board_t*);
#endif
