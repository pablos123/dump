#include "GoLThreads.h"
#include "Board.h"
#include "Game.h"

/*
 * Inicializa cada uno de los elementos de una Thread Structure excepto el candado.
 * */
TSp TSp_initializer(board_t* board, board_t* newBoard, CoordP* coords)
{	
	TSp newTSp = malloc(sizeof(TS));
	
	newTSp->board = board;
	
	newTSp->newBoard = newBoard;
	
	newTSp->coords = coords;

	return newTSp;
}
