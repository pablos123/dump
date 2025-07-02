#include "Game.h"

game_t *loadGame(const char *filename)
{
	char loader[200];
	
	size_t columnCount = 0, rowCount = 0, numberOfCycles = 0, index = 0;

	board_t* newBoard = malloc(sizeof(board_t));
	
	game_t* newGame = malloc(sizeof(game_t));
	
	FILE* inputFile = fopen(filename , "r");
	
	if(inputFile == NULL)
	{
		printf("Missing file.");
		return NULL;
	}	
	
	fscanf(inputFile, "%ld %ld %ld\n", &numberOfCycles, &rowCount, &columnCount);	
	
	char buffer = fgetc(inputFile);
	
	while(!feof(inputFile))
	{
		
		while(buffer != '\n' && buffer != '\r')
		{
			loader[index] = buffer;
			index++;
			
			buffer = fgetc(inputFile);
		}

		buffer = fgetc(inputFile);	
	}
	
	loader[index] = '\0';
		
	board_init_def(newBoard, rowCount, columnCount, DEAD);
	
	board_load(newBoard, loader);
	
	newGame->board = newBoard;

	newGame->cycles = numberOfCycles;
	
	fclose(inputFile);
	
	return newGame;
}

void writeBoard(board_t board, const char *filename)
{
	FILE* outputFile = fopen(filename, "w");
	
	for(int i = 0; i < board.rowCount; i++)
	{
		for(int j = 0; j < board.columnCount; j++)
		{
			fprintf(outputFile,"%c | ", (board.cellStatus)[i][j]);
		}
		fprintf(outputFile, "\n");
	}
	
	fclose(outputFile);
}

board_t *conwayGoL(board_t *board, unsigned int cycles, const int nuproc)
{
	board_t* temporal;
	
	for(int k = 0; k < cycles; k++)
	{	
		board_t* newBoard = malloc(sizeof(board_t));
		//Limpio mi board
		board_init_def(newBoard, board->rowCount, board->columnCount, DEAD);
		printf("Creo el newBoard...%d direc: %p\n", k, newBoard);
		
		for(int i = 0; i < board->rowCount; i++)
		{
			for(int j = 0; j < board->columnCount; j++)
			{
				char currentElementState = board_get(board, i , j);
				
				char newState = get_new_state(board, i, j, currentElementState);
				
				board_set(newBoard, i, j, newState);
				
			}
		}
		
		if(k != 0) 
		{
			temporal = board;
			board = newBoard;
			
			printf("Destruyo el newBoard %d...direc: %p\n", k, temporal);
		
			board_destroy(temporal);
		}
		else
		{
			board = newBoard;
		}
	}
	
	return board;
}


char get_new_state(board_t *board, size_t i, size_t j, char currentElementState)
{
	//punteros a entero que indicaran la cantidad de muertos y vivos rspectivamente
	int* deadNeighbors = malloc(sizeof(int));
	int* aliveNeighbors = malloc(sizeof(int));
	
	//Inicializo los valores
	*deadNeighbors = 0;
	*aliveNeighbors = 0;
	
	char currentNeighbor;
	
	//el tamaño de las columnas y filas es uno mas grandeee no empieza en 0 ://
	int columnCount = board->columnCount - 1;
	
	int rowCount = board->rowCount - 1;
	
	size_t newI, newJ;
	
	//para cada uno de los elementos que quiero encontrar sumare o 
	//restare a i o a j y si el valor esta fuera del rango: [0, n-1] siendo n el 
	//numero de filas o el numero de columnas respectivamente hacemos el modulo
	
	//arriba
	newI = normalize(i - 1, rowCount);
	newJ = normalize(j, columnCount);

	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	//diagonal derecha sup
	newI = normalize(i - 1, rowCount);
	newJ = normalize(j + 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);

	//derecha
	newI = normalize(i, rowCount);
	newJ = normalize(j + 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	//diagonal derecha inf
	newI = normalize(i + 1, rowCount);
	newJ = normalize(j + 1, columnCount);

	currentNeighbor = board_get(board, newI, newJ); //aca se rompe?
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	//abajo
	newI = normalize(i + 1, rowCount);
	newJ = normalize(j, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	//diagonal izquierda inf
	newI = normalize(i + 1, rowCount);
	newJ = normalize(j - 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	//izquierda
	newI = normalize(i, rowCount);
	newJ = normalize(j - 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	//diagonal izquierda sup
	newI = normalize(i - 1, rowCount);
	newJ = normalize(j - 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	if((currentElementState == ALIVE) && ((*aliveNeighbors == 2) || (*aliveNeighbors == 3)))
	{
		free(aliveNeighbors);
		free(deadNeighbors);
		
		return ALIVE;
	}
	
	if((currentElementState == DEAD) && (*aliveNeighbors == 3))
	{
		free(aliveNeighbors);
		free(deadNeighbors);
		
		return ALIVE;
	}

	free(aliveNeighbors);
	free(deadNeighbors);
	
	return DEAD;
}


void addCounter(int* aliveCount, int* deadCount, char cellState)
{	
	if(cellState == DEAD) 
	{
		(*deadCount)++;;
		return; 
	}

	(*aliveCount)++;
	
	return;
}

size_t normalize(int a, size_t max)
{
	size_t newMax = max + 1;
	 
	if(a < 0)
	{
		a = (-1) * a;
		
		return newMax - (a % max);
	}
	
	if(a > max)
	{	
		return newMax - a;  
	}
	
	return a;
}

//Destroys the given game
void game_destroyer(game_t* game)
{
	board_destroy(game->board);
	
	free(game);
}
