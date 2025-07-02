#include "Game.h"

/***********LIBRARIES************/
#include <sys/sysinfo.h>
#include <string.h>

int main(int argc, char **argv)
{	
	if(argc != 2)
	{
		printf("Bad number of parameters.\n");
		return 1;
	}

	game_t* myGame = loadGame(argv[1]);

	if(myGame == NULL)
	{
		printf("Missing file or error in the game file format.\n");
		return 1;
	}

	board_t* finalState = conwayGoL(myGame->board, myGame->cycles, 1);

	//Creamos el nombre del archivo final para cumplir con el formato pedido.
	//Pido 2 mas de memoria para mi caracter vacio y mi string "final".
	char* finalString = malloc(sizeof(char) * ((strlen(argv[1]) + 2))); 

	argv[1][strlen(argv[1]) - 4] = '\0';

	strcpy(finalString, argv[1]);

	writeBoard(*finalState, strcat(finalString, "final"));

	//Ultimos frees de laejecución del programa
	free(finalString);

	board_destroy(finalState);

	game_destroyer(myGame);

	return 0;
}
