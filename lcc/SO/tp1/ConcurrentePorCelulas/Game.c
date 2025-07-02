#include "Game.h"

game_t *loadGame(const char *filename)
{	
	size_t columnCount = 0, rowCount = 0, numberOfCycles = 0, index = 0;

	board_t* newBoard = malloc(sizeof(board_t));
	
	game_t* newGame = malloc(sizeof(game_t));
	
	FILE* inputFile = fopen(filename , "r");
	
	if(inputFile == NULL)
	{
		return NULL;
	}	
	
	int firstRowArguments; 
	firstRowArguments = fscanf(inputFile, "%zu %zu %zu\n", &numberOfCycles, &rowCount, &columnCount);	

	if(firstRowArguments != 3)
	{
		return NULL;
	}

	
	char loader[columnCount * rowCount];
	
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
		
	assert(!board_init_def(newBoard, rowCount, columnCount, DEAD));
	
	assert(!board_load(newBoard, loader));
	
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
			fprintf(outputFile,"%c", (board.cellStatus)[i][j]);
		}
		fprintf(outputFile, "\n");
	}
	
	fclose(outputFile);
}

board_t *conwayGoL(board_t *board, unsigned int cycles, const int nuproc)
{
	//Inicializamos el candado que compartiran nuestros hilos
	pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
	
	//Board que servirá para borrar la memoria de cada uno de los boards de la iteracion
	board_t* temporal;
	
	CoordP* coords = coordArray(board->rowCount, board->columnCount);
	
	for(int k = 0; k < cycles; k++)
	{	
		board_t* newBoard = malloc(sizeof(board_t));
		assert(!board_init_def(newBoard, board->rowCount, board->columnCount, DEAD));
		
		TSp arguments = TSp_initializer(board, newBoard, coords);

		arguments->lock = &lock;

		//Creamos un array de nuproc hilos, luego los creamos
		//e indicamos que ejecuten la función cycle, luego esperamos 
		//que todos terminen.
		pthread_t ts[nuproc];
		
		for(int i = 0; i < nuproc; i++)
		{
			assert(!pthread_create(&ts[i], NULL, cycle, (void*)(arguments)));
		}
		
		for(int i = 0; i < nuproc; i++)
		{
			assert(!pthread_join(ts[i], NULL));
		}
		
		//Liberación de la memoria usada y limpieza del array de coordenadas
		//para que se reutilice.
		if(k != 0) 
		{
			temporal = board;
			board = newBoard;
		
			board_destroy(temporal);
			cleanCoordArray(board->rowCount, board->columnCount, coords);
			free(arguments);
		}
	
		else
		{
			board = newBoard;
			cleanCoordArray(board->rowCount, board->columnCount, coords);
			free(arguments);
		}
	}
	
	destroy_coords(coords, board->rowCount, board->columnCount);
	
	return board;
}

void* cycle(void* TSparg)
{	
	//Los hilos realizaran el siguiente ciclo para buscar celulas disponibles.
	int i, j;
	
	for(int k = 0; k < ((TSp)TSparg)->board->rowCount * ((TSp)TSparg)->board->columnCount; k++)
	{
		//Se bloquea mientras se le asigna (o no) una celula
		//para luego calcular el estado de esta en el siguiente
		//tablero.
		pthread_mutex_lock(((TSp)TSparg)->lock);
		
		/*****************SECCION CRITICA***************************/
		if(((TSp)TSparg)->coords[k]->isChecked == 0)
		{
			((TSp)TSparg)->coords[k]->isChecked = 1;
			
			//Luego de que la coordenada fuera puesta como visitada
			//se desbloquea.
			pthread_mutex_unlock(((TSp)TSparg)->lock);
		/*******************FINALIZA SECCION CRITICA****************/
			
			i = ((TSp)TSparg)->coords[k]->i;
			
			j = ((TSp)TSparg)->coords[k]->j;
			
			char newState = get_new_state(((TSp)TSparg)->board, i, j);
			
			assert(!board_set(((TSp)TSparg)->newBoard, i, j, newState));
		}
		
		//Si la coordenada esta visitada se desbloquea el hilo
		else
			pthread_mutex_unlock(((TSp)TSparg)->lock);
	}
	
	return NULL;
}

char get_new_state(board_t *board, size_t i, size_t j)
{
	char currentElementState = board_get(board, i , j);
	char currentNeighbor;
	
	size_t* deadNeighbors = malloc(sizeof(size_t));
	size_t* aliveNeighbors = malloc(sizeof(size_t));
	
	*deadNeighbors = 0;
	*aliveNeighbors = 0;

	size_t columnCount = board->columnCount - 1;
	
	size_t rowCount = board->rowCount - 1;
	
	size_t newI, newJ;

	//Sumare o restare 1 o 0 a las coordenadas i y j de mi celula actual
	//para moverme hacia las celulas vecinas, luego
	//si el valor esta fuera del rango: [0, n-1] siendo n el 
	//numero de filas o el numero de columnas la función normalize
	//actua en consecuencia.
	//Luego dado el estado de la celula vecina se sumara el contador
	//correspondiente.
	
	//arriba
	newI = normalize(i - 1, rowCount);
	newJ = normalize(j, columnCount);

	currentNeighbor = board_get(board, newI, newJ);
	addCounter(currentNeighbor, aliveNeighbors, deadNeighbors);
	
	//diagonal derecha sup
	newI = normalize(i - 1, rowCount);
	newJ = normalize(j + 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(currentNeighbor, aliveNeighbors, deadNeighbors);

	//derecha
	newI = normalize(i, rowCount);
	newJ = normalize(j + 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(currentNeighbor, aliveNeighbors, deadNeighbors);
	
	//diagonal derecha inf
	newI = normalize(i + 1, rowCount);
	newJ = normalize(j + 1, columnCount);

	currentNeighbor = board_get(board, newI, newJ);
	addCounter(currentNeighbor, aliveNeighbors, deadNeighbors);
	
	//abajo
	newI = normalize(i + 1, rowCount);
	newJ = normalize(j, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(currentNeighbor, aliveNeighbors, deadNeighbors);
	
	//diagonal izquierda inf
	newI = normalize(i + 1, rowCount);
	newJ = normalize(j - 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(currentNeighbor, aliveNeighbors, deadNeighbors);
	
	//izquierda
	newI = normalize(i, rowCount);
	newJ = normalize(j - 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(currentNeighbor, aliveNeighbors, deadNeighbors);
	
	//diagonal izquierda sup
	newI = normalize(i - 1, rowCount);
	newJ = normalize(j - 1, columnCount);
	
	currentNeighbor = board_get(board, newI, newJ);
	addCounter(currentNeighbor, aliveNeighbors, deadNeighbors);
	
	//Condiciones del juego de la vida planteado por John Conway.
	if((currentElementState == ALIVE) && ((*aliveNeighbors == 2) || (*aliveNeighbors == 3)))
	{	
		free(deadNeighbors);
		free(aliveNeighbors);
		
		return ALIVE;
	}
	
	if((currentElementState == DEAD) && (*aliveNeighbors == 3))
	{
		free(deadNeighbors);
		free(aliveNeighbors);
		
		return ALIVE;
	}
	
	free(deadNeighbors);
	free(aliveNeighbors);
	
	return DEAD;
}
	
void addCounter(char cellState, size_t* aliveCounter, size_t* deadCounter)
{	
	if(cellState == DEAD) 
	{
		(*deadCounter)++;
		return; 
	}
	
	(*aliveCounter)++;
}

//Destroys the given game
void game_destroyer(game_t* game)
{
	board_destroy(game->board);
	
	free(game);
}
