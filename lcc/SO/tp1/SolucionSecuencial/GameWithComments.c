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

/** Rules
El juego presenta un tablero bidimensional infinito compuesto por células. Las
células pueden estar *vivas* o *muertas*. Al ser un tablero bidimensional e
infinito, cada célula tiene 8 células vecinas.

En cada momento, las células pasan a estar vivas o muertas siguiendo las reglas:

+ Toda célula viva con 2 o 3 vecinos vivos sobrevive,
+ Toda célula muerta con exactamente con 3 vecinos vivo revive,
+ El resto de las células vivas mueren en la siguiente generación, como a su vez
  el resto de las células muertas se mantienen muertas.
  
El patrón inicial del tablero se le suele llamar *semilla*. La primer generación
es el resultado de aplicar las 3 reglas antes descriptas a todas las células de
la semilla, las transiciones se dan de forma simultanea. Las reglas se siguen
aplicando de la misma manera para obtener futuras generaciones.

Dado que no tenemos la posibilidad de implementar un tablero infinito en una
computadora con recursos limitados, vamos a trabajar con tablero de dimensiones finitas.
Asumimos entonces que las fronteras se comparten, doblando el tablero.
Es decir, la frontera superior **es** la frontera inferior, mientras que la
frontera de la izquierda **es** la frontera de la derecha.

En un tablero *tab* de dimensiones `4 x 4` , la quinta fila sería la primer
fila, mientras que la quinta columna volvería a ser la primer columna. El
pensamiento es similar al que se toman en los mapas para describir el mundo.
 * */

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
	
	//printerlio(board);
	//printerlio(newBoard);
	return board;
}


char get_new_state(board_t *board, size_t i, size_t j, char currentElementState)
{
	printf("%ld %ld|\n", i, j);
	
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
	
	printf("N i: %d    N j: %d\n", newI, newJ);
	printf("current neighbor: %c\n", currentNeighbor);

	//diagonal derecha sup
	newI = normalize(i - 1, rowCount);
	newJ = normalize(j + 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);

	printf("N i: %d    N j: %d\n", newI, newJ);
	printf("current neighbor: %c\n", currentNeighbor);
	
	//derecha
	newI = normalize(i, rowCount);
	newJ = normalize(j + 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	printf("N i: %d    N j: %d\n", newI, newJ);
	printf("current neighbor: %c\n", currentNeighbor);
	
	//diagonal derecha inf
	newI = normalize(i + 1, rowCount);
	newJ = normalize(j + 1, columnCount);

	currentNeighbor = board_get(board, newI, newJ); //aca se rompe?
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	printf("N i: %d    N j: %d\n", newI, newJ);
	printf("current neighbor: %c\n", currentNeighbor);
	
	//abajo
	newI = normalize(i + 1, rowCount);
	newJ = normalize(j, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	printf("N i: %d    N j: %d\n", newI, newJ);
	printf("current neighbor: %c\n", currentNeighbor);
	
	//diagonal izquierda inf
	newI = normalize(i + 1, rowCount);
	newJ = normalize(j - 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	printf("N i: %d    N j: %d\n", newI, newJ);
	printf("current neighbor: %c\n", currentNeighbor);
	
	//izquierda
	newI = normalize(i, rowCount);
	newJ = normalize(j - 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	printf("N i: %d    N j: %d\n", newI, newJ);
	printf("current neighbor: %c\n", currentNeighbor);
	
	//diagonal izquierda sup
	newI = normalize(i - 1, rowCount);
	newJ = normalize(j - 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(aliveNeighbors, deadNeighbors, currentNeighbor);
	
	printf("N i: %d    N j: %d\n", newI, newJ);
	printf("current neighbor: %c\n", currentNeighbor);
	
	printf("alive: %d, dead: %d\n", *aliveNeighbors, *deadNeighbors);
	printf("current element state%c\n", currentElementState);
	
	if((currentElementState == ALIVE) && ((*aliveNeighbors == 2) || (*aliveNeighbors == 3)))
	{
		return ALIVE;
	}
	
	if((currentElementState == DEAD) && (*aliveNeighbors == 3))
	{
		return ALIVE;
	}

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
		printf("sdf");
		a = (-1) * a;
		
		return newMax - (a % max);
	}
	
	if(a > max)
	{	
		return newMax - a;  
	}
	
	return a;
}

void game_destroyer(game_t* game)
{
	board_destroy(game->board);
	
	free(game);
}
