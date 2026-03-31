%{
/*
   Compiler Project – CPL to MIPS
   Authors: Natali Shamunov 207893496 | Or Tal Adani 314669615

   File: parser.y
   Description:
   This file defines the grammar of the CPL language using Bison.
   It performs syntax analysis, semantic checks, and generates MIPS code.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symtab.h"

/* Lexer function */
int yylex(void);

/* Error reporting function */
void yyerror(const char *s);

/* Global counters and tracking variables imported from other files */
extern int syntaxErrors;
extern int semanticErrors;
extern int num_of_line;
extern char lastTokenText[256];
extern int lastTokenColumn;
extern char lastTokenKind[64];
extern char previousTokenText[256];
extern FILE *lstFile;
extern FILE *outFile;

/* Current declaration type while parsing variable declarations */
static int currentDeclType = TYPE_UNDEF;

/* Counter used to generate unique labels for jumps/branches */
static int labelCounter = 0;

/* Counter used to generate unique labels for string literals */
static int stringCounter = 0;

/* Creates a unique label for a string constant (e.g., str0, str1, ...) */
static void newStringLabel(char *buf)
{
    sprintf(buf, "str%d", stringCounter++);
}

/* Counter used to generate unique labels for real constants */
static int realCounter = 0;

/* Creates a unique label for a real constant (e.g., real0, real1, ...) */
static void newRealLabel(char *buf)
{
    sprintf(buf, "real%d", realCounter++);
}

/* Labels used for the current IF statement */
static char currentIfFalseLabel[20];
static char currentIfEndLabel[20];

/* Labels used for the current WHILE loop */
static char whileStartLabel[20];
static char whileEndLabel[20];

/* Labels used for the current FOR loop */
static char forStartLabel[20];
static char forEndLabel[20];

/* Labels used for the current DO-TILL loop */
static char doStartLabel[20];
static char doEndLabel[20];

/* Saved information about FOR loop step expression */
static char forVarName[50];
static char forOp[5];
static char forStepValue[50];

/* Global variables used for SWITCH statement code generation */
static char switchVar[50];
static char switchChoiceValue[50];
static int switchIsImmediate = 0;
static char switchEndLabel[20];

/* Creates a new unique jump label (e.g., L0, L1, ...) */
static void newLabel(char *buf)
{
    sprintf(buf, "L%d", labelCounter++);
}

/* Returns the type of a numeric literal: int or real */
static int number_type(const char *s)
{
    if (strchr(s, '.') != NULL)
        return TYPE_REAL;
    return TYPE_INT;
}

/* Returns a readable name for a type, for use in error messages */
static const char *type_name(int t)
{
    switch (t)
    {
        case TYPE_INT: return "int";
        case TYPE_REAL: return "real";
        case TYPE_STRING: return "string";
        default: return "undefined";
    }
}

/* Checks whether a type is numeric */
static int is_numeric_type(int t)
{
    return (t == TYPE_INT || t == TYPE_REAL);
}

/* Merges two numeric types:
   if one is real, the result is real; otherwise int */
static int merge_numeric_types(int a, int b)
{
    if (a == TYPE_REAL || b == TYPE_REAL)
        return TYPE_REAL;
    return TYPE_INT;
}

/* Reports a semantic error to the listing file and increments the counter */
static void report_semantic_error(const char *msg)
{
    semanticErrors++;
    if (lstFile != NULL)
        fprintf(lstFile, "ERROR line %d: %s\n", num_of_line, msg);
}
%}

/* Semantic value types used by grammar symbols */
%union {
    char *str;
    int type;
}

/* Tokens */
%token MAIN START END
%token <str> ID
%token <str> NUM
%token <str> SENTENCE

%token BREAK CASE CONST DEFAULT DO ELSE FOR IF INT
%token PRINT REAL READ STRING SWITCH TILL THEN VAR WHILE WHEN
%token <str> RELOP ADDOP MULOP
%token ASSIGNOP OROP ANDOP

/* Non-terminals with semantic values */
%type <type> TYPE
%type <type> EXPRESSION TERM FACTOR
%type <type> RELTEST BOOLEXPR BOOLTERM BOOLFACTOR

/* Operator precedence and associativity */
%left OROP
%left ANDOP
%left RELOP
%left ADDOP
%left MULOP
%right '!'

%%

/* Entire program structure */
PROGRAM
    : MAIN ID START
      {
          /* Start MIPS data section */
          if (outFile != NULL)
              fprintf(outFile, ".data\n");
      }
      DECLARATIONS
      {
          /* Start MIPS text section and main label */
          if (outFile != NULL)
              fprintf(outFile, "\n.text\n.globl main\nmain:\n");
      }
      STMTLIST END
      {
          /* Emit program termination syscall */
          if (outFile != NULL)
          {
              fprintf(outFile, "\n# program end\n");
              fprintf(outFile, "li $v0, 10\n");
              fprintf(outFile, "syscall\n");
          }
      }
    ;

/* Optional declarations section */
DECLARATIONS
    : VAR DECLARLIST CDECL
    | /* epsilon */
    ;

/* One or more variable declarations */
DECLARLIST
    : DECLARLIST DECL
    | DECL
    ;

/* Single declaration */
DECL
    : TYPE ':' LIST
      {
          /* Reset declaration type after finishing declaration list */
          currentDeclType = TYPE_UNDEF;
      }
    | TYPE error ';'
      {
          /* Recover from declaration syntax error */
          currentDeclType = TYPE_UNDEF;
          yyerrok;
      }
    ;

/* Variable list in a declaration line */
LIST
    : ID ',' LIST
      {
          /* Insert declared variable into symbol table */
          if (!insertSymbol($1, currentDeclType, 0))
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "variable '%s' declared more than once", $1);
              report_semantic_error(msg);
          }
          else if (outFile != NULL)
          {
              /* Emit storage allocation in data section */
              if (currentDeclType == TYPE_REAL)
                  fprintf(outFile, "%s: .float 0.0\n", $1);
              else
                  fprintf(outFile, "%s: .word 0\n", $1);
          }
      }
    | ID ';'
      {
          /* Insert last variable in declaration list */
          if (!insertSymbol($1, currentDeclType, 0))
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "variable '%s' declared more than once", $1);
              report_semantic_error(msg);
          }
          else if (outFile != NULL)
          {
              /* Emit storage allocation in data section */
              if (currentDeclType == TYPE_REAL)
                  fprintf(outFile, "%s: .float 0.0\n", $1);
              else
                  fprintf(outFile, "%s: .word 0\n", $1);
          }
      }
    ;

/* Supported variable types */
TYPE
    : INT
      {
          $$ = TYPE_INT;
          currentDeclType = TYPE_INT;
      }
    | REAL
      {
          $$ = TYPE_REAL;
          currentDeclType = TYPE_REAL;
      }
    | STRING
      {
          $$ = TYPE_STRING;
          currentDeclType = TYPE_STRING;
      }
    ;
	
/* Constant declarations */
CDECL
    : CONST TYPE ID ASSIGNOP NUM ';' CDECL
      {
          int numType = number_type($5);

          /* Insert constant into symbol table */
          if (!insertSymbol($3, $2, 1))
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "constant '%s' declared more than once", $3);
              report_semantic_error(msg);
          }
          else
          {
              /* Validate constant initialization type */
              if (!($2 == numType || ($2 == TYPE_REAL && numType == TYPE_INT)))
              {
                  char msg[256];
                  snprintf(msg, sizeof(msg),
                           "illegal constant initialization for '%s' (cannot assign %s to %s)",
                           $3, type_name(numType), type_name($2));
                  report_semantic_error(msg);
              }
              else if (outFile != NULL)
              {
                  /* Emit constant allocation and initialization */
                  if ($2 == TYPE_REAL)
                  {
                      if (numType == TYPE_REAL)
                          fprintf(outFile, "%s: .float %s\n", $3, $5);
                      else
                          fprintf(outFile, "%s: .float %s.0\n", $3, $5);
                  }
                  else
                  {
                      fprintf(outFile, "%s: .word %s\n", $3, $5);
                  }
              }
          }
      }
    | CONST error ';' CDECL
      {
          /* Recover from const declaration syntax error */
          yyerrok;
      }
    | /* epsilon */
    ;

/* Sequence of statements */
STMTLIST
    : STMTLIST STMT
    | /* epsilon */
    ;

/* Supported statement types */
STMT
    : ASSIGNMENT_STMT
    | STRING_ASSIGNMENT_STMT
    | CONTROL_STMT
    | READ_STMT
    | WRITE_STMT
    | STMT_BLOCK
    | error ';'
      {
          /* Recover from statement syntax error */
          yyerrok;
      }
    ;

/* Statement block enclosed in braces */
STMT_BLOCK
    : '{' STMTLIST '}'
    ;

/* Assignment of a string literal to a string variable */
STRING_ASSIGNMENT_STMT
    : ID ASSIGNOP SENTENCE ';'
      {
          Symbol *sym = lookupSymbol($1);

          /* Semantic checks for string assignment */
          if (sym == NULL)
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "identifier '%s' was not declared", $1);
              report_semantic_error(msg);
          }
          else if (sym->isConst)
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "cannot assign to constant '%s'", $1);
              report_semantic_error(msg);
          }
          else if (sym->type != TYPE_STRING)
          {
              char msg[256];
              snprintf(msg, sizeof(msg),
                       "illegal assignment: cannot assign string to %s variable '%s'",
                       type_name(sym->type), $1);
              report_semantic_error(msg);
          }
          else if (outFile != NULL)
          {
              /* Emit string literal into data section and store its address */
              char lbl[20];
              newStringLabel(lbl);

              fprintf(outFile, "\n.data\n");
              fprintf(outFile, "%s: .asciiz %s\n", lbl, $3);
              fprintf(outFile, ".text\n");
              fprintf(outFile, "la $t0,%s\n", lbl);
              fprintf(outFile, "sw $t0,%s\n", $1);
          }
      }
    ;

/* Print statement */
WRITE_STMT
    : PRINT '(' EXPRESSION ')' ';'
      {
          if (outFile != NULL)
          {
              /* Print according to evaluated expression type */
              if ($3 == TYPE_STRING)
              {
                  fprintf(outFile, "move $a0,$t0\n");
                  fprintf(outFile, "li $v0,4\n");
                  fprintf(outFile, "syscall\n");
              }
              else if ($3 == TYPE_REAL)
              {
                  fprintf(outFile, "mov.s $f12,$f0\n");
                  fprintf(outFile, "li $v0,2\n");
                  fprintf(outFile, "syscall\n");
              }
              else
              {
                  fprintf(outFile, "move $a0,$t0\n");
                  fprintf(outFile, "li $v0,1\n");
                  fprintf(outFile, "syscall\n");
              }
          }
      }
    | PRINT '(' SENTENCE ')' ';'
      {
          if (outFile != NULL)
          {
              /* Print a direct string literal */
              char lbl[20];
              newStringLabel(lbl);

              fprintf(outFile, "\n.data\n");
              fprintf(outFile, "%s: .asciiz %s\n", lbl, $3);
              fprintf(outFile, ".text\n");
              fprintf(outFile, "la $a0,%s\n", lbl);
              fprintf(outFile, "li $v0,4\n");
              fprintf(outFile, "syscall\n");
          }
      }
    ;
	
/* Read statement */
READ_STMT
    : READ '(' ID ')' ';'
      {
          Symbol *sym = lookupSymbol($3);

          /* Semantic checks for read target */
          if (sym == NULL)
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "identifier '%s' was not declared", $3);
              report_semantic_error(msg);
          }
          else if (sym->isConst)
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "cannot read into constant '%s'", $3);
              report_semantic_error(msg);
          }
          else
          {
              if (outFile != NULL)
              {
                  /* Emit syscall for reading int or real */
                  if (sym->type == TYPE_REAL)
                  {
                      fprintf(outFile, "li $v0,6\n");
                      fprintf(outFile, "syscall\n");
                      fprintf(outFile, "s.s $f0,%s\n", $3);
                  }
                  else
                  {
                      fprintf(outFile, "li $v0,5\n");
                      fprintf(outFile, "syscall\n");
                      fprintf(outFile, "sw $v0,%s\n", $3);
                  }
              }
          }
      }
    ;

/* Numeric assignment statement */
ASSIGNMENT_STMT
    : ID ASSIGNOP EXPRESSION ';'
      {
          Symbol *sym = lookupSymbol($1);

          /* Semantic checks for assignment */
          if (sym == NULL)
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "identifier '%s' was not declared", $1);
              report_semantic_error(msg);
          }
          else if (sym->isConst)
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "cannot assign to constant '%s'", $1);
              report_semantic_error(msg);
          }
          else if (!(sym->type == $3 || (sym->type == TYPE_REAL && $3 == TYPE_INT)))
          {
              char msg[256];
              snprintf(msg, sizeof(msg),
                       "illegal assignment: cannot assign %s expression to %s variable '%s'",
                       type_name($3), type_name(sym->type), $1);
              report_semantic_error(msg);
          }
          else if (outFile != NULL)
          {
              /* Emit assignment code, including int-to-real conversion if needed */
              if (sym->type == TYPE_REAL)
              {
                  if ($3 == TYPE_REAL)
                  {
                      fprintf(outFile, "s.s $f0,%s\n", $1);
                  }
                  else
                  {
                      fprintf(outFile, "mtc1 $t0,$f0\n");
                      fprintf(outFile, "cvt.s.w $f0,$f0\n");
                      fprintf(outFile, "s.s $f0,%s\n", $1);
                  }
              }
              else
              {
                  fprintf(outFile, "sw $t0,%s\n", $1);
              }
          }
      }
    ;

/* Control statements: IF, WHILE, FOR, DO-TILL, SWITCH */
CONTROL_STMT
    : IF '(' BOOLEXPR ')' THEN
      {
          /* Create labels for IF-ELSE control flow */
          newLabel(currentIfFalseLabel);
          newLabel(currentIfEndLabel);

          if (outFile != NULL)
              fprintf(outFile, "beq $t0,$zero,%s\n", currentIfFalseLabel);
      }
      STMT
      {
          /* Jump over ELSE part after THEN finishes */
          if (outFile != NULL)
          {
              fprintf(outFile, "j %s\n", currentIfEndLabel);
              fprintf(outFile, "%s:\n", currentIfFalseLabel);
          }
      }
      ELSE STMT
      {
          /* End label for IF-ELSE */
          if (outFile != NULL)
              fprintf(outFile, "%s:\n", currentIfEndLabel);

          currentIfFalseLabel[0] = '\0';
          currentIfEndLabel[0] = '\0';
      }
    | WHILE
      {
          /* Create start and end labels for WHILE loop */
          newLabel(whileStartLabel);
          newLabel(whileEndLabel);

          if (outFile != NULL)
              fprintf(outFile, "%s:\n", whileStartLabel);
      }
      '(' BOOLEXPR ')'
      {
          /* Exit loop if condition is false */
          if (outFile != NULL)
              fprintf(outFile, "beq $t0,$zero,%s\n", whileEndLabel);
      }
      STMT_BLOCK
      {
          /* Repeat loop and mark exit point */
          if (outFile != NULL)
          {
              fprintf(outFile, "j %s\n", whileStartLabel);
              fprintf(outFile, "%s:\n", whileEndLabel);
          }

          whileStartLabel[0] = '\0';
          whileEndLabel[0] = '\0';
      }
    | FOR '(' FOR_ASSIGN ';'
      {
          /* Create start and end labels for FOR loop */
          newLabel(forStartLabel);
          newLabel(forEndLabel);

          if (outFile != NULL)
              fprintf(outFile, "%s:\n", forStartLabel);
      }
      BOOLEXPR ';'
      {
          /* Exit FOR loop if condition is false */
          if (outFile != NULL)
              fprintf(outFile, "beq $t0,$zero,%s\n", forEndLabel);
      }
      STEP ')' STMT_BLOCK
      {
          if (outFile != NULL)
          {
              /* Apply FOR step update after loop body */
              fprintf(outFile, "lw $t0,%s\n", forVarName);
              fprintf(outFile, "addi $sp,$sp,-4\n");
              fprintf(outFile, "sw $t0,0($sp)\n");
              fprintf(outFile, "li $t0,%s\n", forStepValue);
              fprintf(outFile, "move $t1,$t0\n");
              fprintf(outFile, "lw $t0,0($sp)\n");
              fprintf(outFile, "addi $sp,$sp,4\n");

              if (strcmp(forOp, "+") == 0)
                  fprintf(outFile, "add $t0,$t0,$t1\n");
              else if (strcmp(forOp, "-") == 0)
                  fprintf(outFile, "sub $t0,$t0,$t1\n");
              else if (strcmp(forOp, "*") == 0)
                  fprintf(outFile, "mul $t0,$t0,$t1\n");
              else
              {
                  fprintf(outFile, "div $t0,$t1\n");
                  fprintf(outFile, "mflo $t0\n");
              }

              fprintf(outFile, "sw $t0,%s\n", forVarName);
              fprintf(outFile, "j %s\n", forStartLabel);
              fprintf(outFile, "%s:\n", forEndLabel);
          }

          /* Clear saved FOR data */
          forStartLabel[0] = '\0';
          forEndLabel[0] = '\0';
          forVarName[0] = '\0';
          forOp[0] = '\0';
          forStepValue[0] = '\0';
      }
    | DO
      {
          /* Create labels for DO-TILL loop */
          newLabel(doStartLabel);
          newLabel(doEndLabel);

          if (outFile != NULL)
              fprintf(outFile, "%s:\n", doStartLabel);
      }
      STMT_BLOCK TILL '(' BOOLEXPR ')'
      {
          if (outFile != NULL)
          {
              /* Exit if condition is true, otherwise repeat */
              fprintf(outFile, "bne $t0,$zero,%s\n", doEndLabel);
              fprintf(outFile, "j %s\n", doStartLabel);
              fprintf(outFile, "%s:\n", doEndLabel);
          }

          doStartLabel[0] = '\0';
          doEndLabel[0] = '\0';
      }
    | SWITCH_STMT
    ;

/* Boolean OR expressions */
BOOLEXPR
    : BOOLEXPR OROP BOOLTERM
      {
          if (outFile != NULL)
          {
              /* Evaluate logical OR */
              fprintf(outFile, "addi $sp,$sp,-4\n");
              fprintf(outFile, "sw $t0,0($sp)\n");
              fprintf(outFile, "move $t1,$t0\n");
              fprintf(outFile, "lw $t0,0($sp)\n");
              fprintf(outFile, "addi $sp,$sp,4\n");
              fprintf(outFile, "or $t0,$t0,$t1\n");
              fprintf(outFile, "sne $t0,$t0,$zero\n");
          }
          $$ = TYPE_INT;
      }
    | BOOLTERM
      {
          $$ = TYPE_INT;
      }
    ;

/* Boolean AND expressions */
BOOLTERM
    : BOOLTERM ANDOP BOOLFACTOR
      {
          if (outFile != NULL)
          {
              /* Evaluate logical AND */
              fprintf(outFile, "addi $sp,$sp,-4\n");
              fprintf(outFile, "sw $t0,0($sp)\n");
              fprintf(outFile, "move $t1,$t0\n");
              fprintf(outFile, "lw $t0,0($sp)\n");
              fprintf(outFile, "addi $sp,$sp,4\n");
              fprintf(outFile, "and $t0,$t0,$t1\n");
              fprintf(outFile, "sne $t0,$t0,$zero\n");
          }
          $$ = TYPE_INT;
      }
    | BOOLFACTOR
      {
          $$ = TYPE_INT;
      }
    ;

/* Boolean factor: NOT, parenthesized expression, or relational test */
BOOLFACTOR
    : '!' BOOLFACTOR
      {
          /* Logical negation */
          if (outFile != NULL)
              fprintf(outFile, "seq $t0,$t0,$zero\n");
          $$ = TYPE_INT;
      }
    | '(' BOOLEXPR ')'
      {
          $$ = TYPE_INT;
      }
    | RELTEST
      {
          $$ = TYPE_INT;
      }
    ;
	
/* Relational comparison between two arithmetic expressions */
RELTEST
    : EXPRESSION RELOP
      {
          if (outFile != NULL)
          {
              /* Save left operand before parsing right operand */
              if ($1 == TYPE_REAL)
                  fprintf(outFile, "addi $sp,$sp,-4\ns.s $f0,0($sp)\n");
              else
                  fprintf(outFile, "addi $sp,$sp,-4\nsw $t0,0($sp)\n");
          }
      }
      EXPRESSION
      {
          if (!is_numeric_type($1) || !is_numeric_type($4))
              report_semantic_error("relational operator requires numeric expressions");

          if (outFile != NULL)
          {
              if ($1 == TYPE_REAL || $4 == TYPE_REAL)
              {
                  char trueLabel[20], endLabel[20];
                  newLabel(trueLabel);
                  newLabel(endLabel);

                  /* Mixed or real comparison: convert ints to float if necessary */
                  if ($4 == TYPE_INT)
                  {
                      fprintf(outFile, "mtc1 $t0,$f1\n");
                      fprintf(outFile, "cvt.s.w $f1,$f1\n");
                  }
                  else
                  {
                      fprintf(outFile, "mov.s $f1,$f0\n");
                  }

                  if ($1 == TYPE_REAL)
                  {
                      fprintf(outFile, "l.s $f0,0($sp)\n");
                  }
                  else
                  {
                      fprintf(outFile, "lw $t1,0($sp)\n");
                      fprintf(outFile, "mtc1 $t1,$f0\n");
                      fprintf(outFile, "cvt.s.w $f0,$f0\n");
                  }

                  fprintf(outFile, "addi $sp,$sp,4\n");

                  /* Emit floating-point comparison code with legal MARS labels */
                  if (strcmp($2, ">") == 0)
                  {
                      fprintf(outFile, "c.le.s $f0,$f1\n");
                      fprintf(outFile, "bc1t %s\n", trueLabel);
                      fprintf(outFile, "li $t0,1\n");
                      fprintf(outFile, "j %s\n", endLabel);
                      fprintf(outFile, "%s:\n", trueLabel);
                      fprintf(outFile, "li $t0,0\n");
                      fprintf(outFile, "%s:\n", endLabel);
                  }
                  else if (strcmp($2, "<") == 0)
                  {
                      fprintf(outFile, "c.lt.s $f0,$f1\n");
                      fprintf(outFile, "bc1t %s\n", trueLabel);
                      fprintf(outFile, "li $t0,0\n");
                      fprintf(outFile, "j %s\n", endLabel);
                      fprintf(outFile, "%s:\n", trueLabel);
                      fprintf(outFile, "li $t0,1\n");
                      fprintf(outFile, "%s:\n", endLabel);
                  }
                  else if (strcmp($2, "==") == 0)
                  {
                      fprintf(outFile, "c.eq.s $f0,$f1\n");
                      fprintf(outFile, "bc1t %s\n", trueLabel);
                      fprintf(outFile, "li $t0,0\n");
                      fprintf(outFile, "j %s\n", endLabel);
                      fprintf(outFile, "%s:\n", trueLabel);
                      fprintf(outFile, "li $t0,1\n");
                      fprintf(outFile, "%s:\n", endLabel);
                  }
                  else if (strcmp($2, "!=") == 0)
                  {
                      fprintf(outFile, "c.eq.s $f0,$f1\n");
                      fprintf(outFile, "bc1t %s\n", trueLabel);
                      fprintf(outFile, "li $t0,1\n");
                      fprintf(outFile, "j %s\n", endLabel);
                      fprintf(outFile, "%s:\n", trueLabel);
                      fprintf(outFile, "li $t0,0\n");
                      fprintf(outFile, "%s:\n", endLabel);
                  }
                  else if (strcmp($2, ">=") == 0)
                  {
                      fprintf(outFile, "c.lt.s $f0,$f1\n");
                      fprintf(outFile, "bc1t %s\n", trueLabel);
                      fprintf(outFile, "li $t0,1\n");
                      fprintf(outFile, "j %s\n", endLabel);
                      fprintf(outFile, "%s:\n", trueLabel);
                      fprintf(outFile, "li $t0,0\n");
                      fprintf(outFile, "%s:\n", endLabel);
                  }
                  else if (strcmp($2, "<=") == 0)
                  {
                      fprintf(outFile, "c.le.s $f0,$f1\n");
                      fprintf(outFile, "bc1t %s\n", trueLabel);
                      fprintf(outFile, "li $t0,0\n");
                      fprintf(outFile, "j %s\n", endLabel);
                      fprintf(outFile, "%s:\n", trueLabel);
                      fprintf(outFile, "li $t0,1\n");
                      fprintf(outFile, "%s:\n", endLabel);
                  }
              }
              else
              {
                  /* Integer comparison */
                  fprintf(outFile, "move $t1,$t0\n");
                  fprintf(outFile, "lw $t0,0($sp)\n");
                  fprintf(outFile, "addi $sp,$sp,4\n");

                  if (strcmp($2, ">") == 0)
                      fprintf(outFile, "sgt $t0,$t0,$t1\n");
                  else if (strcmp($2, "<") == 0)
                      fprintf(outFile, "slt $t0,$t0,$t1\n");
                  else if (strcmp($2, "==") == 0)
                      fprintf(outFile, "seq $t0,$t0,$t1\n");
                  else if (strcmp($2, "!=") == 0)
                      fprintf(outFile, "sne $t0,$t0,$t1\n");
                  else if (strcmp($2, ">=") == 0)
                      fprintf(outFile, "sge $t0,$t0,$t1\n");
                  else if (strcmp($2, "<=") == 0)
                      fprintf(outFile, "sle $t0,$t0,$t1\n");
              }
          }

          $$ = TYPE_INT;
      }
    ;

/* Initialization part of FOR loop */
FOR_ASSIGN
    : ID ASSIGNOP EXPRESSION
      {
          Symbol *sym = lookupSymbol($1);

          /* Save loop control variable name */
          strcpy(forVarName, $1);

          /* Semantic checks for FOR initialization */
          if (sym == NULL)
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "identifier '%s' was not declared", $1);
              report_semantic_error(msg);
          }
          else if (sym->isConst)
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "cannot assign to constant '%s'", $1);
              report_semantic_error(msg);
          }
          else if (!(sym->type == $3 || (sym->type == TYPE_REAL && $3 == TYPE_INT)))
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "illegal assignment in for-init for '%s'", $1);
              report_semantic_error(msg);
          }
          else if (outFile != NULL)
          {
              fprintf(outFile, "sw $t0,%s\n", $1);
          }
      }
    ;

/* SWITCH statement with variable or immediate numeric selector */
SWITCH_STMT
    : SWITCH '(' ID ')'
      {
          /* Switch on variable value */
          strcpy(switchVar, $3);
          switchChoiceValue[0] = '\0';
          switchIsImmediate = 0;
          newLabel(switchEndLabel);
      }
      '{' CASE_LIST DEFAULT ':' STMTLIST '}'
      {
          /* End of switch */
          if (outFile != NULL)
              fprintf(outFile, "%s:\n", switchEndLabel);
      }
    | SWITCH '(' NUM ')'
      {
          /* Switch on immediate numeric value */
          switchVar[0] = '\0';
          strcpy(switchChoiceValue, $3);
          switchIsImmediate = 1;
          newLabel(switchEndLabel);
      }
      '{' CASE_LIST DEFAULT ':' STMTLIST '}'
      {
          /* End of switch */
          if (outFile != NULL)
              fprintf(outFile, "%s:\n", switchEndLabel);
      }
    ;

/* List of CASE branches */
CASE_LIST
    : CASE_LIST CASE_STMT
    | CASE_STMT
    ;

/* Single CASE branch with BREAK */
CASE_STMT
    : CASE NUM ':'
      {
          char caseLabel[20];
          char nextLabel[20];

          /* Create labels for matching case and skipping to next case */
          newLabel(caseLabel);
          newLabel(nextLabel);

          if (outFile != NULL)
          {
              if (switchIsImmediate)
                  fprintf(outFile, "li $t0,%s\n", switchChoiceValue);
              else
                  fprintf(outFile, "lw $t0,%s\n", switchVar);

              fprintf(outFile, "li $t1,%s\n", $2);
              fprintf(outFile, "beq $t0,$t1,%s\n", caseLabel);
              fprintf(outFile, "j %s\n", nextLabel);
              fprintf(outFile, "%s:\n", caseLabel);
          }

          /* Reuse currentIfFalseLabel to remember where next case starts */
          strcpy(currentIfFalseLabel, nextLabel);
      }
      STMTLIST BREAK ';'
      {
          if (outFile != NULL)
          {
              /* Jump to switch end after executing matched case */
              fprintf(outFile, "j %s\n", switchEndLabel);
              fprintf(outFile, "%s:\n", currentIfFalseLabel);
          }
      }
    ;

/* FOR loop step update pattern */
STEP
    : ID ASSIGNOP ID ADDOP NUM
      {
          /* Save additive step operator and value */
          strcpy(forOp, $4);
          strcpy(forStepValue, $5);
      }
    | ID ASSIGNOP ID MULOP NUM
      {
          /* Save multiplicative step operator and value */
          strcpy(forOp, $4);
          strcpy(forStepValue, $5);
      }
    ;

/* Arithmetic expression with addition/subtraction */
EXPRESSION
    : EXPRESSION ADDOP
      {
          /* Save left operand before evaluating right operand */
          if ($1 == TYPE_REAL)
          {
              if (outFile != NULL)
                  fprintf(outFile, "addi $sp,$sp,-4\ns.s $f0,0($sp)\n");
          }
          else
          {
              if (outFile != NULL)
                  fprintf(outFile, "addi $sp,$sp,-4\nsw $t0,0($sp)\n");
          }
      }
      TERM
      {
          if (!is_numeric_type($1) || !is_numeric_type($4))
          {
              report_semantic_error("arithmetic expression requires numeric operands");
              $$ = TYPE_UNDEF;
          }
          else
          {
              $$ = merge_numeric_types($1,$4);

              if (outFile != NULL)
              {
                  if ($$ == TYPE_REAL)
                  {
                      /* Real arithmetic: convert operands as needed */
                      if ($4 == TYPE_INT)
                      {
                          fprintf(outFile,"mtc1 $t0,$f1\n");
                          fprintf(outFile,"cvt.s.w $f1,$f1\n");
                      }
                      else
                          fprintf(outFile,"mov.s $f1,$f0\n");

                      if ($1 == TYPE_REAL)
                          fprintf(outFile,"l.s $f0,0($sp)\n");
                      else
                      {
                          fprintf(outFile,"lw $t1,0($sp)\n");
                          fprintf(outFile,"mtc1 $t1,$f0\n");
                          fprintf(outFile,"cvt.s.w $f0,$f0\n");
                      }

                      fprintf(outFile,"addi $sp,$sp,4\n");

                      if (strcmp($2,"+")==0)
                          fprintf(outFile,"add.s $f0,$f0,$f1\n");
                      else
                          fprintf(outFile,"sub.s $f0,$f0,$f1\n");
                  }
                  else
                  {
                      /* Integer arithmetic */
                      fprintf(outFile,"move $t1,$t0\n");
                      fprintf(outFile,"lw $t0,0($sp)\n");
                      fprintf(outFile,"addi $sp,$sp,4\n");

                      if (strcmp($2,"+")==0)
                          fprintf(outFile,"add $t0,$t0,$t1\n");
                      else
                          fprintf(outFile,"sub $t0,$t0,$t1\n");
                  }
              }
          }
      }
    | TERM
      {
          $$ = $1;
      }
    ;
	
/* Arithmetic term with multiplication/division */
TERM
    : TERM MULOP
      {
          /* Save left operand before evaluating right operand */
          if ($1 == TYPE_REAL)
          {
              if (outFile != NULL)
                  fprintf(outFile,"addi $sp,$sp,-4\ns.s $f0,0($sp)\n");
          }
          else
          {
              if (outFile != NULL)
                  fprintf(outFile,"addi $sp,$sp,-4\nsw $t0,0($sp)\n");
          }
      }
      FACTOR
      {
          if (!is_numeric_type($1) || !is_numeric_type($4))
          {
              report_semantic_error("arithmetic term requires numeric operands");
              $$ = TYPE_UNDEF;
          }
          else
          {
              $$ = merge_numeric_types($1,$4);

              if (outFile != NULL)
              {
                  if ($$ == TYPE_REAL)
                  {
                      /* Real multiplication/division */
                      if ($4 == TYPE_INT)
                      {
                          fprintf(outFile,"mtc1 $t0,$f1\n");
                          fprintf(outFile,"cvt.s.w $f1,$f1\n");
                      }
                      else
                          fprintf(outFile,"mov.s $f1,$f0\n");

                      if ($1 == TYPE_REAL)
                          fprintf(outFile,"l.s $f0,0($sp)\n");
                      else
                      {
                          fprintf(outFile,"lw $t1,0($sp)\n");
                          fprintf(outFile,"mtc1 $t1,$f0\n");
                          fprintf(outFile,"cvt.s.w $f0,$f0\n");
                      }

                      fprintf(outFile,"addi $sp,$sp,4\n");

                      if (strcmp($2,"*")==0)
                          fprintf(outFile,"mul.s $f0,$f0,$f1\n");
                      else
                          fprintf(outFile,"div.s $f0,$f0,$f1\n");
                  }
                  else
                  {
                      /* Integer multiplication/division */
                      fprintf(outFile,"move $t1,$t0\n");
                      fprintf(outFile,"lw $t0,0($sp)\n");
                      fprintf(outFile,"addi $sp,$sp,4\n");

                      if (strcmp($2,"*")==0)
                          fprintf(outFile,"mul $t0,$t0,$t1\n");
                      else
                      {
                          fprintf(outFile,"div $t0,$t1\n");
                          fprintf(outFile,"mflo $t0\n");
                      }
                  }
              }
          }
      }
    | FACTOR
      {
          $$ = $1;
      }
    ;

/* Smallest arithmetic unit */
FACTOR
    : '(' EXPRESSION ')'
      {
          $$ = $2;
      }
    | ID
      {
          Symbol *sym = lookupSymbol($1);

          /* Load variable value from memory */
          if (sym == NULL)
          {
              char msg[256];
              snprintf(msg, sizeof(msg), "identifier '%s' was not declared", $1);
              report_semantic_error(msg);
              $$ = TYPE_UNDEF;
          }
          else
          {
              $$ = sym->type;
              if (outFile != NULL)
              {
                  if (sym->type == TYPE_REAL)
                      fprintf(outFile, "l.s $f0,%s\n", $1);
                  else
                      fprintf(outFile, "lw $t0,%s\n", $1);
              }
          }
      }
    | NUM
      {
          /* Load numeric literal */
          $$ = number_type($1);
          if (outFile != NULL)
          {
              if ($$ == TYPE_REAL)
              {
                  char lbl[20];
                  newRealLabel(lbl);

                  fprintf(outFile, "\n.data\n");
                  fprintf(outFile, "%s: .float %s\n", lbl, $1);
                  fprintf(outFile, ".text\n");
                  fprintf(outFile, "l.s $f0,%s\n", lbl);
              }
              else
              {
                  fprintf(outFile, "li $t0,%s\n", $1);
              }
          }
      }
    ;

%%

/* Reports syntax errors to the listing file with improved formatting */
void yyerror(const char *s)
{
    syntaxErrors++;

    if (lstFile != NULL)
    {
        /* Suppress duplicate error on 'else' after previous syntax issue */
        if (strcmp(lastTokenText, "else") == 0)
        {
            return;
        }
        /* Special message for missing '(' after IF */
        else if (strcmp(previousTokenText, "if") == 0 &&
                 strcmp(lastTokenKind, "identifier") == 0)
        {
            fprintf(lstFile,
                    "ERROR line %d, column %d: Expected '(', found identifier instead.\n",
                    num_of_line, lastTokenColumn);
        }
        /* Standard detailed syntax error with token kind and text */
        else if (lastTokenText[0] != '\0' && lastTokenKind[0] != '\0')
        {
            fprintf(lstFile,
                    "ERROR line %d, column %d: syntax error near %s '%s'\n",
                    num_of_line, lastTokenColumn, lastTokenKind, lastTokenText);
        }
        /* Fallback: token text only */
        else if (lastTokenText[0] != '\0')
        {
            fprintf(lstFile,
                    "ERROR line %d, column %d: syntax error near '%s'\n",
                    num_of_line, lastTokenColumn);
        }
        /* Final fallback: generic Bison error text */
        else
        {
            fprintf(lstFile,
                    "ERROR line %d, column %d: %s\n",
                    num_of_line, lastTokenColumn, s);
        }
    }
}