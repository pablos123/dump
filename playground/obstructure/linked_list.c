#include <stdlib.h>
#include <stdio.h>
#include "linked_list.h"

linked_list_t* linked_list_create() {
    return NULL;
}

void linked_list_create_node(linked_list_t* node) {

    char* name = calloc(26, sizeof(char));
    sprintf(name, "./nodes/%p.md", node);

    FILE *fp;
    fp = fopen (name, "w");
    if(node->next_node != NULL)
        fprintf(fp, "%u\n[[%p]]\n", node->value, node->next_node);
    else
        fprintf(fp, "%u\nNULL\n", node->value);

    fclose(fp);
    free(name);
}

linked_list_t* linked_list_add_start(linked_list_t* linked_list, unsigned value) {

    linked_list_t* new_node = calloc(1, sizeof(struct linked_list_t));

    new_node->value = value;
    new_node->next_node = linked_list;

    linked_list_create_node(new_node);

    return new_node;
}

linked_list_t* linked_list_add_end(linked_list_t* linked_list, unsigned value) {

    linked_list_t* new_node = calloc(1, sizeof(struct linked_list_t));

    new_node->value = value;
    new_node->next_node = NULL;

    if(linked_list == NULL) {
        linked_list_create_node(new_node);
        return new_node;
    }

    linked_list_t* iter_node = linked_list;

    while((iter_node->next_node) != NULL) {
        iter_node = iter_node->next_node;
    }

    iter_node->next_node = new_node;

    linked_list_create_node(iter_node);
    linked_list_create_node(new_node);

    return linked_list;
}


void linked_list_print(linked_list_t* linked_list) {

    if(linked_list == NULL) {
        printf("Empty list!\n");
        return;
    }

    linked_list_t* iter_node = linked_list;
    while(iter_node->next_node != NULL) {
        printf("%p (%u) -> ", iter_node, iter_node->value);
        iter_node = iter_node->next_node;
    }

    printf("%p (%u) -> NULL", iter_node, iter_node->value);
}

void linked_list_destruct(linked_list_t* linked_list) {

    linked_list_t* iter_node = linked_list;

    while(iter_node != NULL) {
        linked_list_t* tmp = iter_node;
        iter_node = tmp->next_node;
        free(tmp);
    }
}
