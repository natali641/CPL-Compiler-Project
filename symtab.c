/*
   Compiler Project – CPL to MIPS
   Authors: Natali Shamunov 207893496 | Or Tal Adani 314669615

   File: symtab.c
   Description:
   This file implements the symbol table of the compiler.
   It supports initialization, insertion, lookup, printing,
   and memory cleanup for symbols such as variables and constants.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symtab.h"

/* Hash table used to store all symbols */
static Symbol *table[HASH_SIZE];

/* Computes a hash value for a given symbol name */
static unsigned int hashFunction(const char *name)
{
    unsigned int hash = 0;

    while (*name != '\0')
    {
        hash = (hash * 31u + (unsigned char)(*name)) % HASH_SIZE;
        name++;
    }

    return hash;
}

/* Initializes the symbol table by setting all buckets to NULL */
void initSymbolTable(void)
{
    int i;

    for (i = 0; i < HASH_SIZE; i++)
        table[i] = NULL;
}

/* Frees all dynamically allocated symbols from the table */
void freeSymbolTable(void)
{
    int i;

    for (i = 0; i < HASH_SIZE; i++)
    {
        Symbol *current = table[i];

        while (current != NULL)
        {
            Symbol *temp = current;
            current = current->next;
            free(temp);
        }

        table[i] = NULL;
    }
}

/* Searches for a symbol by name and returns it if found */
Symbol *lookupSymbol(const char *name)
{
    unsigned int index = hashFunction(name);
    Symbol *current = table[index];

    while (current != NULL)
    {
        if (strcmp(current->name, name) == 0)
            return current;

        current = current->next;
    }

    return NULL;
}

/* Inserts a new symbol into the table
   Returns 1 on success, 0 if the symbol already exists */
int insertSymbol(const char *name, int type, int isConst)
{
    unsigned int index = hashFunction(name);
    Symbol *newSymbol;

    /* Prevent duplicate declarations */
    if (lookupSymbol(name) != NULL)
        return 0;

    /* Allocate memory for the new symbol */
    newSymbol = (Symbol *)malloc(sizeof(Symbol));
    if (newSymbol == NULL)
    {
        fprintf(stderr, "Memory allocation error\n");
        exit(1);
    }

    /* Copy symbol information */
    strncpy(newSymbol->name, name, sizeof(newSymbol->name) - 1);
    newSymbol->name[sizeof(newSymbol->name) - 1] = '\0';
    newSymbol->type = type;
    newSymbol->isConst = isConst;

    /* Insert symbol at the beginning of the linked list in its hash bucket */
    newSymbol->next = table[index];
    table[index] = newSymbol;

    return 1;
}

/* Prints the current symbol table for debugging and testing */
void printSymbolTable(void)
{
    int i;

    printf("\nSymbol Table:\n");
    printf("----------------------\n");

    for (i = 0; i < HASH_SIZE; i++)
    {
        Symbol *current = table[i];

        while (current != NULL)
        {
            printf("Name: %s  Type: %s  Const: %d\n",
                   current->name,
                   getTypeName(current->type),
                   current->isConst);

            current = current->next;
        }
    }

    printf("----------------------\n");
}

/* Returns the textual representation of a symbol type */
const char *getTypeName(int type)
{
    switch (type)
    {
        case TYPE_INT: return "int";
        case TYPE_REAL: return "real";
        case TYPE_STRING: return "string";
        case TYPE_BOOL: return "bool";
        default: return "undef";
    }
}