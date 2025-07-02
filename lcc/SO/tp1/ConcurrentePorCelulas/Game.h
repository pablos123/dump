#ifndef GAME
#define GAME

#include "Board.h"
#include "GoLThreads.h"

/******************************************************************************/
/* Representamos las células vivas como 'O' y las muertas como 'X' 
 * */
#define ALIVE 'O'
#define DEAD 'X'

/******************************************************************************/
/* La estructura de un juego es simplemente un tablero y la cantidad de veces
 * que se va a iterar 
* */
struct _game {
  board_t *board;
  long unsigned int cycles;
};
typedef struct _game game_t;

/******************************************************************************/
/* Cargamos el juego desde un archivo 
 * */
game_t *loadGame(const char *filename);

/* Guardamos el tablero 'board' en el archivo 'filename' 
 * */
void writeBoard(board_t board, const char *filename);

/*
 * Simulamos el Juego de la Vida de Conway con tablero 'board' la cantidad de
 * ciclos indicados en 'cycles' en 'nuprocs' unidades de procesamiento
 * */
board_t *conwayGoL(board_t *board, unsigned int cycles, const int nuproc);

/*
 * El ciclo principal que realizarán los hilos. Toma un puntero a void que en nuestro caso
 * luego castearemosa un puntero TSp definido en el archivo GoLThreads.h. En esta función
 * se creará el board de la siguiente generación.
 * */
void* cycle(void* TSparg);

/*
 * Toma un puntero a un tablero indicando el tablero actual en el cual buscar
 * el elemento en la posición ij representada por dos numero enterosno negativos.
 * */
char get_new_state(board_t *board, size_t i, size_t j);

/*
 * Suma uno a los contadores de células vivas o células muertas dado el parámetro cellState.
 * */
void addCounter(char cellState, size_t* aliveCounter, size_t* deadCounter);

/*
 * Destroys game.
 * */
void game_destroyer(game_t*);
#endif
