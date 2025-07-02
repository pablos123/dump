#include <stdio.h>
#include <stdlib.h>
#include "linked_list.h"

void clean_nodes();

int main() {
    char operation = 0;
    printf("OBSTRUCTURE: a data structure visualization for obsidian writen in C\n");
    printf("Insert operation:\na: add a node to the start\nr: remove a node\nc: close the program\ne: add a node to the end\n");

    linked_list_t* linked_list = linked_list_create();

    unsigned counter = 0;
    while(1) {

        scanf("%c", &operation);
        if(operation == 'a')
            linked_list = linked_list_add_start(linked_list, counter++);

        if(operation == 'e')
            linked_list = linked_list_add_end(linked_list, counter++);

        if(operation == 'p')
            linked_list_print(linked_list);

        if(operation == 'c')
            break;

    }

    linked_list_destruct(linked_list);

    clean_nodes();

    return 0;
}


void clean_nodes() {
    system("rm -f $HOME/obstructure/nodes/*");
}
