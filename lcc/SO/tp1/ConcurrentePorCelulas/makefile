all: main

main: main.c Game.o Board.o GoLThreads.o GoLCoords.o
	gcc -g -o simulador main.c Game.c Board.c GoLThreads.c GoLCoords.c -Wall -pedantic -pthread

Game.o: Game.c
	gcc -g -c Game.c -Wall -pedantic -pthread -O

Board.o: Board.c
	gcc -g -c Board.c -Wall -pedantic -pthread -O

GoLThreads.o: GoLThreads.c
	gcc -g -c GoLThreads.c -Wall -pedantic -pthread -O

GoLCoords.o: GoLCoords.c
	gcc -g -c GoLCoords.c -Wall -pedantic -pthread

.PHONY: clean
clean:
	rm -rf *.o
	rm -rf *.out
	rm -f simulador
