#include <sys/sysinfo.h>
#include "Game.h"

int main(int argc, char **argv)
{
	
	//hacer copia de myGame->board
	
	if(argc != 2)
	{
		printf("Bad number of parameters.");
		return 1;
	}
	
	game_t* myGame = loadGame(argv[1]);

	printf("Direccion entrante %p:\n", myGame->board);
	board_t* finalState = conwayGoL(myGame->board, myGame->cycles, get_nprocs());

	char* finalString = malloc(sizeof(char) * (strlen(argv[1]) + 10));
	
	strcpy(finalString, argv[1]);
	
	writeBoard(*finalState, strcat(finalString, ".final"));
	
	//Free space of the last board.
	printf("Destruyendo el ultimo board.... direc: %p\n", finalState);
	board_destroy(finalState);
	
	game_destroyer(myGame);
	
	return 0;
}
