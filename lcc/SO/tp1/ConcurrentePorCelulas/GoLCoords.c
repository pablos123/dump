#include "GoLCoords.h"

size_t normalize(int a, size_t max)
{
	//Al estar trabajando con matrices finitas planteadas como en el enunciado.
	//Se consideran con estas dos condiciones los casos borde.
	//Si nuestra fila o columna es la anterior a la primer devolveré la última.
	//Si nuestra fila o columna es la siguietne a la última devolveré la primera.
	
	if(a < 0)
	{
		return max;
	}

	if(a > max)
	{	
		return 0;  
	}

	return a;
}

CoordP* coordArray(size_t rowCount, size_t columnCount)
{
	CoordP* newCoordArray = malloc(sizeof(CoordP) * rowCount * columnCount);
	
	size_t k = 0;
	
	for(size_t i = 0; i < rowCount; i++)
	{
		for(size_t j = 0; j < columnCount; j++)
		{
			CoordP newCoord = malloc(sizeof(Coord));
			
			newCoord->i = i;
			newCoord->j = j;
			//todas nuestras coodenadas estarán seteadas en 0 al 
			//comenzar la busqueda para utilizarlas.
			newCoord->isChecked = 0;
			
			newCoordArray[k] = newCoord;
			k++;
		}
	}
	
	return newCoordArray; //Devuelve un array de la forma {(i,j,F) : i < rowCount, j < columnCount}
}

void destroy_coords(CoordP* coords, size_t rows, size_t columns)
{
	for(int i = 0; i < rows * columns; i++)
	{
		free(coords[i]);
	}
	
	free(coords);
}


CoordP* cleanCoordArray(size_t rowCount, size_t columnCount, CoordP* coordArray)
{
	for(int i = 0; i < rowCount * columnCount; i++)
	{
		//todas nuestras coodenadas estarán seteadas en 0 al 
		//al volver a comenzar la busqueda para utilizarlas.
		coordArray[i]->isChecked = 0;
	}
	
	return coordArray;
}

