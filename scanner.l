%{
/*
   Compiler Project – CPL to MIPS
   Authors: Natali Shamunov 207893496 | Or Tal Adani 314669615

   File: scanner.l
   Description:
   This file defines the lexical analyzer of the CPL compiler using Flex.
   It identifies tokens, updates line/column tracking, writes source lines
   to the listing file, and reports lexical errors.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.tab.h"

/* Global variables imported from cpm.c */
extern FILE *lstFile;
extern int num_of_line;
extern int num_of_column;
extern int lexicalErrors;
extern char lastTokenText[256];
extern char currentLineText[1024];
extern int lastTokenColumn;
extern char lastTokenKind[64];
extern char previousTokenText[256];

/* Semantic value structure imported from Bison */
extern YYSTYPE yylval;

/* Appends text to the current source line buffer for the listing file */
static void append_to_current_line(const char *text)
{
    size_t cur_len = strlen(currentLineText);
    size_t add_len = strlen(text);

    if (cur_len + add_len >= 1023)
        add_len = 1023 - cur_len;

    strncat(currentLineText, text, add_len);
}

/* Writes the current source line to the listing file and clears the buffer */
static void flush_listing_line(void)
{
    if (lstFile != NULL)
    {
        fprintf(lstFile, "%d. %s\n", num_of_line, currentLineText);
        currentLineText[0] = '\0';
    }
}

/* Advances the current column number according to the matched text length */
static void advance_column_by_text(const char *text)
{
    num_of_column += (int)strlen(text);
}

/* Reports a lexical error to the listing file and increments the error counter */
static void report_lexical_error(const char *msg, const char *bad_text, int line, int col)
{
    lexicalErrors++;

    if (lstFile != NULL)
    {
        fprintf(lstFile, "ERROR line %d, column %d: %s: %s\n",
                line, col, msg, bad_text);
    }
}

/* Saves the text of the last scanned token */
static void save_last_token(const char *text)
{
    strncpy(lastTokenText, text, 255);
    lastTokenText[255] = '\0';
}

/* Saves the kind of the last scanned token */
static void save_last_token_kind(const char *kind)
{
    strncpy(lastTokenKind, kind, 63);
    lastTokenKind[63] = '\0';
}

/* Moves the last token text into previousTokenText before scanning a new token */
static void shift_previous_token(void)
{
    strncpy(previousTokenText, lastTokenText, 255);
    previousTokenText[255] = '\0';
}

/* Updates token tracking information, listing text, and columns */
static void add_token_to_listing_and_columns(const char *kind)
{
    shift_previous_token();
    lastTokenColumn = num_of_column;
    append_to_current_line(yytext);
    save_last_token(yytext);
    save_last_token_kind(kind);
    advance_column_by_text(yytext);
}
%}

%option noinput nounput noyywrap

DIGIT      [0-9]
LETTER     [A-Za-z]
ID         {LETTER}({LETTER}|{DIGIT})*
NUM        {DIGIT}+(\.{DIGIT}*)?
WS         [ \t]+
SENTENCE   \"[A-Za-z0-9\.\,\!\?\ ]*\"
COMMENT    "/*"([^*\n\r]|\*+[^*/\n\r]|\r|\n)*"*"+"/"

%%

"main"      { add_token_to_listing_and_columns("keyword"); return MAIN; }
"start"     { add_token_to_listing_and_columns("keyword"); return START; }
"end"       { add_token_to_listing_and_columns("keyword"); return END; }

"break"     { add_token_to_listing_and_columns("keyword"); return BREAK; }
"case"      { add_token_to_listing_and_columns("keyword"); return CASE; }
"const"     { add_token_to_listing_and_columns("keyword"); return CONST; }
"default"   { add_token_to_listing_and_columns("keyword"); return DEFAULT; }
"do"        { add_token_to_listing_and_columns("keyword"); return DO; }
"else"      { add_token_to_listing_and_columns("keyword"); return ELSE; }
"for"       { add_token_to_listing_and_columns("keyword"); return FOR; }
"if"        { add_token_to_listing_and_columns("keyword"); return IF; }
"int"       { add_token_to_listing_and_columns("keyword"); return INT; }
"print"     { add_token_to_listing_and_columns("keyword"); return PRINT; }
"real"      { add_token_to_listing_and_columns("keyword"); return REAL; }
"read"      { add_token_to_listing_and_columns("keyword"); return READ; }
"string"    { add_token_to_listing_and_columns("keyword"); return STRING; }
"switch"    { add_token_to_listing_and_columns("keyword"); return SWITCH; }
"till"      { add_token_to_listing_and_columns("keyword"); return TILL; }
"then"      { add_token_to_listing_and_columns("keyword"); return THEN; }
"var"       { add_token_to_listing_and_columns("keyword"); return VAR; }
"while"     { add_token_to_listing_and_columns("keyword"); return WHILE; }
"when"      { add_token_to_listing_and_columns("keyword"); return WHEN; }

"=="        { add_token_to_listing_and_columns("operator"); yylval.str = strdup(yytext); return RELOP; }
"!="        { add_token_to_listing_and_columns("operator"); yylval.str = strdup(yytext); return RELOP; }
"<="        { add_token_to_listing_and_columns("operator"); yylval.str = strdup(yytext); return RELOP; }
">="        { add_token_to_listing_and_columns("operator"); yylval.str = strdup(yytext); return RELOP; }
"<"         { add_token_to_listing_and_columns("operator"); yylval.str = strdup(yytext); return RELOP; }
">"         { add_token_to_listing_and_columns("operator"); yylval.str = strdup(yytext); return RELOP; }

"+"         { add_token_to_listing_and_columns("operator"); yylval.str = strdup(yytext); return ADDOP; }
"-"         { add_token_to_listing_and_columns("operator"); yylval.str = strdup(yytext); return ADDOP; }

"*"         { add_token_to_listing_and_columns("operator"); yylval.str = strdup(yytext); return MULOP; }
"/"         { add_token_to_listing_and_columns("operator"); yylval.str = strdup(yytext); return MULOP; }

":="        { add_token_to_listing_and_columns("operator"); return ASSIGNOP; }
"||"        { add_token_to_listing_and_columns("operator"); return OROP; }
"&&"        { add_token_to_listing_and_columns("operator"); return ANDOP; }

"("         { add_token_to_listing_and_columns("symbol"); return '('; }
")"         { add_token_to_listing_and_columns("symbol"); return ')'; }
"{"         { add_token_to_listing_and_columns("symbol"); return '{'; }
"}"         { add_token_to_listing_and_columns("symbol"); return '}'; }
","         { add_token_to_listing_and_columns("symbol"); return ','; }
":"         { add_token_to_listing_and_columns("symbol"); return ':'; }
";"         { add_token_to_listing_and_columns("symbol"); return ';'; }
"!"         { add_token_to_listing_and_columns("symbol"); return '!'; }

{SENTENCE}  {
                add_token_to_listing_and_columns("string");
                yylval.str = strdup(yytext);
                return SENTENCE;
            }

{NUM}       {
                add_token_to_listing_and_columns("number");
                yylval.str = strdup(yytext);
                return NUM;
            }

{ID}        {
                int start_col = num_of_column;

                shift_previous_token();
                lastTokenColumn = start_col;
                append_to_current_line(yytext);
                save_last_token(yytext);
                save_last_token_kind("identifier");
                advance_column_by_text(yytext);

                if ((int)strlen(yytext) > 9)
                {
                    report_lexical_error("identifier too long", yytext, num_of_line, start_col);
                }
                else
                {
                    yylval.str = strdup(yytext);
                    return ID;
                }
            }

{COMMENT}   {
                int i;
                for (i = 0; yytext[i] != '\0'; i++)
                {
                    if (yytext[i] == '\r')
                    {
                        if (yytext[i + 1] == '\n')
                            i++;

                        flush_listing_line();
                        num_of_line++;
                        num_of_column = 1;
                    }
                    else if (yytext[i] == '\n')
                    {
                        flush_listing_line();
                        num_of_line++;
                        num_of_column = 1;
                    }
                    else
                    {
                        num_of_column++;
                    }
                }
            }

{WS}        {
                append_to_current_line(yytext);
                advance_column_by_text(yytext);
            }

\r\n        {
                flush_listing_line();
                num_of_line++;
                num_of_column = 1;
            }

\r          {
                flush_listing_line();
                num_of_line++;
                num_of_column = 1;
            }

\n          {
                flush_listing_line();
                num_of_line++;
                num_of_column = 1;
            }

<<EOF>>     {
                if (currentLineText[0] != '\0')
                    flush_listing_line();
                return 0;
            }

.           {
                int err_col = num_of_column;

                shift_previous_token();
                lastTokenColumn = err_col;
                append_to_current_line(yytext);
                save_last_token(yytext);
                save_last_token_kind("illegal");
                advance_column_by_text(yytext);

                report_lexical_error("illegal character", yytext, num_of_line, err_col);
            }

%%