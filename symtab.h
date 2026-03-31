#ifndef SYMTAB_H
#define SYMTAB_H

/*
   Compiler Project – CPL to MIPS
   Authors: Natali Shamunov 207893496 | Or Tal Adani 314669615

   File: symtab.h
   Description:
   This header file defines the symbol table interface.
   It includes type definitions, constants, the Symbol structure,
   and function declarations used by the compiler.
*/

#include <stdio.h>

/* Supported data types in the compiler */
#define TYPE_UNDEF   0
#define TYPE_INT     1
#define TYPE_REAL    2
#define TYPE_STRING  3
#define TYPE_BOOL    4

/* Size of the hash table used for symbol storage */
#define HASH_SIZE 211

/* Structure representing a single symbol in the symbol table */
typedef struct Symbol
{
    char name[10];         /* Symbol name (up to 9 characters + '\0') */
    int type;              /* Symbol type: int, real, string, bool, or undefined */
    int isConst;           /* Indicates whether the symbol is a constant */
    struct Symbol *next;   /* Pointer to the next symbol in the same hash bucket */
} Symbol;

/* Initializes the symbol table */
void initSymbolTable(void);

/* Frees all allocated memory used by the symbol table */
void freeSymbolTable(void);

/* Searches for a symbol by name */
Symbol *lookupSymbol(const char *name);

/* Inserts a new symbol into the table */
int insertSymbol(const char *name, int type, int isConst);

/* Prints the symbol table contents */
void printSymbolTable(void);

/* Returns the textual name of a given type */
const char *getTypeName(int type);

#endif