#include "Board.h"

int board_init_def(board_t *board, size_t row, size_t col, char def)
{
	board->rowCount = row;
	
	board->columnCount = col;
	
	board->cellStatus = malloc(sizeof(char*) * row);
	
	for(int i = 0; i < row; i++)
	{
		board->cellStatus[i] = malloc(sizeof(char) * col);
	}
	
	for(int i = 0; i < board->rowCount; i++)
	{
		for(int j = 0; j < board->columnCount; j++)
		{
			(board->cellStatus)[i][j] = def;
		}
	}	
	
	return 0;
}

void board_printer(board_t* board)
{
	
	for(int i = 0; i < board->rowCount; i++)
	{
		for(int j = 0; j < board->columnCount; j++)
		{
			printf("%c | ", (board->cellStatus)[i][j]);
		}
		printf("\n");
	}
	
return;
}

char board_get(board_t *board, size_t row, size_t col)
{
	return board->cellStatus[row][col];
}

int board_set(board_t *board, size_t row, size_t col, char val)
{
	board->cellStatus[row][col] = val;
	
	return 0;
}

int board_load(board_t *board, char *str)
{
	int strIndex = 0; 
	
	for(int i = 0; i < board->rowCount; ++i)
	{
		for(int j = 0; j < board->columnCount; ++j)
		{
			board->cellStatus[i][j] = str[strIndex];
			strIndex++;
		}
	}
	
	return 0;
}

void board_show(board_t board, char *answer)
{
	int strIndex = 0; 
	
	for(int i = 0; i < board.rowCount; ++i)
	{
		for(int j = 0; j < board.columnCount; ++j)
		{
			answer[strIndex] = board.cellStatus[i][j];
			strIndex++;
		}
	}
}

void board_destroy(board_t *board)
{
	for(int i = 0; i < board->rowCount; i++)
	{
		free(board->cellStatus[i]);
	}
	
	free(board->cellStatus);
	
	free(board);
}
