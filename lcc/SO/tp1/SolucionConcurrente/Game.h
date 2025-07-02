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

/*
 * Estructura para los hilos
 * */

typedef struct{
  pthread_mutex_t* lock;
  int* deadCounter;
  int* aliveCounter;
  size_t i;
  size_t j;
  board_t* myBoard;
  }TS;
  
typedef TS* TSp;


/******************************************************************************/

/* Cargamos el juego desde un archivo */ //archivo de entrada
game_t *loadGame(const char *filename);

/* Guardamos el tablero 'board' en el archivo 'filename' */ //archivo de salida
void writeBoard(board_t board, const char *filename);

/* Simulamos el Juego de la Vida de Conway con tablero 'board' la cantidad de
ciclos indicados en 'cycles' en 'nuprocs' unidades de procesamiento*/ //hace todo
board_t *conwayGoL(board_t *board, unsigned int cycles, const int nuproc);

char get_new_state(board_t *board, size_t i, size_t j, char currentElementState, const int);

size_t normalize(int a, size_t max);

void addCounter(char cellState, TSp sd);

void game_destroyer(game_t*);

TSp TSp_initializer(board_t* board, size_t, size_t, int*, int*);

void* check_neighbors(void* TSparg);
