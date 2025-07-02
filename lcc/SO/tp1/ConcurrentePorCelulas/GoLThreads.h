#ifndef GOLTHREADS
#define GOLTHREADS

#include "GoLCoords.h"
#include "Board.h"

#include <pthread.h>
#include <assert.h>

/******************************************************************************/
/*
 * Estructura para el argumento de los hilos.
 * Contiene un candado, para poder bloquear los hilos dentro de la sección crítica.
 * Un Array de punteros a estructuras de tipo CoordP, el cual servirá para evitar que los hilos se comporten de manera errónea.
 * Un puntero a un tablero, representando el tablero de la iteración anterior.
 * Un puntero a un tablero, representando el tablero de la iteración actural
 * */
typedef struct{
  pthread_mutex_t* lock;
  CoordP* coords;
  board_t* board;
  board_t* newBoard;
  }TS;
  
typedef TS* TSp;

/*************************************************************************/

/*
 * Inicializa cada uno de los elementos de una Thread Structure excepto el candado.
 * */
TSp TSp_initializer(board_t* board, board_t* newBoard, CoordP*);

#endif
