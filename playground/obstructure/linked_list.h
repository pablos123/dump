typedef struct linked_list_t {
    unsigned value;
    struct linked_list_t* next_node;
} linked_list_t;

linked_list_t* linked_list_create();

linked_list_t* linked_list_add_start(linked_list_t* linked_list, unsigned value);

linked_list_t* linked_list_add_end(linked_list_t* linked_list, unsigned value);

linked_list_t* linked_list_remove_start(linked_list_t* linked_list, unsigned value);

linked_list_t* linked_list_remove_end(linked_list_t* linked_list, unsigned value);

void linked_list_print(linked_list_t* linked_list);

void linked_list_create_node(linked_list_t* node);

void linked_list_destruct(linked_list_t* linked_list);
