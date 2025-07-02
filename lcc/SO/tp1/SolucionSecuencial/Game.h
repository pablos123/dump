#include "Board.h"

/******************************************************************************/
/* Representamos las células vivas como 'O' y las muertas como 'X' */
#define ALIVE 'O'
#define DEAD 'X'
/******************************************************************************/
/* La estructura de un juego es simplemente un tablero y la cantidad de veces
que se va a iterar */
struct _game {
  board_t *board;
  long unsigned int cycles;
};

typedef struct _game game_t;
/******************************************************************************/

/* Cargamos el juego desde un archivo */ //archivo de entrada
game_t *loadGame(const char *filename);

/* Guardamos el tablero 'board' en el archivo 'filename' */ //archivo de salida
void writeBoard(board_t board, const char *filename);

/* Simulamos el Juego de la Vida de Conway con tablero 'board' la cantidad de
ciclos indicados en 'cycles' en 'nuprocs' unidades de procesamiento*/ //hace todo
board_t *conwayGoL(board_t *board, unsigned int cycles, const int nuproc);

char get_new_state(board_t *board, size_t i, size_t j, char currentElementState);

size_t normalize(int a, size_t max);

void addCounter(int* aliveCount, int* deadCount, char cellState);

void game_destroyer(game_t*);
