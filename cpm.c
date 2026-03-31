/* 
   Compiler Project – CPL to MIPS
   Authors: Natali Shamunov 207893496 | Or Tal Adani 314669615

   File: cpm.c
   Description:
   This is the main file of the compiler.
   It is responsible for validating the input file, opening the needed files,
   initializing global counters and data structures, running the parser,
   and handling final cleanup and output file deletion when errors exist.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symtab.h"

/* Functions imported from lexer/parser */
extern int yyparse(void);
extern FILE *yyin;
extern void yyrestart(FILE *input_file);

/* Global files shared with scanner and parser */
FILE *lstFile = NULL;
FILE *outFile = NULL;

/* Global counters and compiler state */
int num_of_line = 1;
int num_of_column = 1;
int lexicalErrors = 0;
int syntaxErrors = 0;
int semanticErrors = 0;

/* Shared buffers used for improved error reporting */
char lastTokenText[256] = "";
char currentLineText[1024] = "";
int lastTokenColumn = 1; 
char lastTokenKind[64] = "";
char previousTokenText[256] = "";

/* Required stamp line written to stderr / listing / output file */
static const char *STAMP =
    "Natali Shamunov 207893496 | Or Tal Adani 314669615";

/* Checks whether the input filename ends with .cpl or .CPL */
static int has_valid_cpl_extension(const char *filename)
{
    const char *dot = strrchr(filename, '.');
    if (dot == NULL)
        return 0;

    return (strcmp(dot, ".cpl") == 0 || strcmp(dot, ".CPL") == 0);
}

/* Builds an output filename by replacing the original extension
   with a new extension such as .lst or .s */
static void build_output_name(char *dest, size_t dest_size,
                              const char *input_name,
                              const char *new_ext)
{
    const char *dot = strrchr(input_name, '.');
    size_t base_len;

    if (dot == NULL)
        base_len = strlen(input_name);
    else
        base_len = (size_t)(dot - input_name);

    /* Prevent buffer overflow in output filename creation */
    if (base_len + strlen(new_ext) + 1 > dest_size)
    {
        fprintf(stderr, "%s\n", STAMP);
        fprintf(stderr, "Interface error: file name is too long.\n");
        exit(1);
    }

    strncpy(dest, input_name, base_len);
    dest[base_len] = '\0';
    strcat(dest, new_ext);
}

/* Safely closes a file only if it is currently open */
static void close_if_open(FILE **fp)
{
    if (fp != NULL && *fp != NULL)
    {
        fclose(*fp);
        *fp = NULL;
    }
}

/* Deletes a file if it exists */
static void delete_file_if_exists(const char *filename)
{
    if (filename != NULL)
        remove(filename);
}

int main(int argc, char *argv[])
{
    char lstName[512];
    char outName[512];
    FILE *inputFile = NULL;
    int totalErrors;

    /* Print required stamp line to stderr */
    fprintf(stderr, "%s\n", STAMP);

    /* Validate number of command-line arguments */
    if (argc != 2)
    {
        fprintf(stderr, "Usage: cpm <file_name>.cpl\n");
        return 1;
    }

    /* Validate input file extension */
    if (!has_valid_cpl_extension(argv[1]))
    {
        fprintf(stderr, "Interface error: input file must have .cpl or .CPL extension.\n");
        return 1;
    }

    /* Open input source file */
    inputFile = fopen(argv[1], "r");
    if (inputFile == NULL)
    {
        fprintf(stderr, "Interface error: cannot open input file '%s'.\n", argv[1]);
        return 1;
    }

    /* Create output file names */
    build_output_name(lstName, sizeof(lstName), argv[1], ".lst");
    build_output_name(outName, sizeof(outName), argv[1], ".s");

    /* Open listing file */
    lstFile = fopen(lstName, "w");
    if (lstFile == NULL)
    {
        fprintf(stderr, "Interface error: cannot create listing file '%s'.\n", lstName);
        fclose(inputFile);
        return 1;
    }

    /* Open assembly output file */
    outFile = fopen(outName, "w");
    if (outFile == NULL)
    {
        fprintf(stderr, "Interface error: cannot create output file '%s'.\n", outName);
        fclose(inputFile);
        close_if_open(&lstFile);
        return 1;
    }

    /* Write stamp line to output files */
    fprintf(lstFile, "%s\n", STAMP);
    fprintf(outFile, "# %s\n\n", STAMP);

    /* Connect lexer input to the source file */
    yyin = inputFile;
    yyrestart(inputFile);

    /* Reset compiler counters and shared buffers before parsing */
    num_of_line = 1;
    num_of_column = 1;
    lexicalErrors = 0;
    syntaxErrors = 0;
    semanticErrors = 0;
    lastTokenText[0] = '\0';
    currentLineText[0] = '\0';
    lastTokenKind[0] = '\0';
    previousTokenText[0] = '\0';
    lastTokenColumn = 1;

    /* Initialize symbol table before parsing starts */
    initSymbolTable();

    /* Run parsing + semantic analysis + code generation */
    yyparse();

    /* Count all error types together */
    totalErrors = lexicalErrors + syntaxErrors + semanticErrors;

    /* Release symbol table memory */
    freeSymbolTable();

    /* Close all open files */
    fclose(inputFile);
    close_if_open(&lstFile);
    close_if_open(&outFile);

    /* If any errors were found, delete the generated .s file */
    if (totalErrors > 0)
    {
        delete_file_if_exists(outName);
        return 1;
    }

    return 0;
}