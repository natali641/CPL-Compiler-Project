# CPL-Compiler-Project
Compiler project for CPL language using Flex and Bison, including lexical analysis, syntax analysis, semantic checks, and MIPS code generation.

**Students**
Natali Shamunov - ID: 207893496 | mail: Natalizigzag1@gmail.com 
Or Tal Adani - ID: 314669615| mail: Ortalia2108@gmail.com 

**Course**
Compilation and Translation
**Lecturer**
Dr. Rina Tzviael Grishin

**Project Description**
This project implements a compiler for the CPL (Compiler Project Language).
The compiler performs lexical, syntactic, and semantic analysis, and generates MIPS assembly code for valid input programs.
The symbol table is implemented as a hash table with chaining, allowing efficient insertion and lookup of identifiers.

**Compilation Instructions**
Compile the project using the following commands:
bison -d parser.y
flex scanner.l
gcc lex.yy.c parser.tab.c symtab.c cpm.c -o cpm.exe

**Running the Compiler**
To run the compiler:
./cpm.exe <file_name>.cpl or cpm.exe <file_name>.cpl
Example:
cpm.exe test_if.cpl
Command format:
cpm.exe <file_name>.cpl

**Input**
- The compiler receives a single input file
-	File extension must be: .cpl or .CPL

**Output**
The compiler produces two output files:
1.	Listing file (.lst)
-	Contains the source code with line numbers
-	Includes error messages (if any)
2.	Assembly file (.s)
-	Contains generated MIPS code
-	Created only if there are no errors
The generated MIPS code was tested using the MARS simulator to verify correctness.

**Error Handling**
The compiler handles:
-	Lexical errors
-	Syntax errors
-	Semantic errors
If any error occurs:
-	The error is printed to the screen and to the .lst file
-	The .s file is not created
The compiler was tested on multiple valid and invalid inputs, including programs with a large number of identifiers (250+), to ensure correctness and robustness.

**Project Structure**
-	scanner.l - lexical analyzer (Flex)
-	parser.y - syntax analyzer (Bison)
-	symtab.c / symtab.h - symbol table implementation
-	cpm.c - main program

**Use of AI Tools**
AI tools (ChatGPT, Gemini) were used as auxiliary tools only, mainly for:
-	Understanding theoretical concepts
-	Debugging assistance
-	Clarifying error messages
All implementation, design decisions, and integration were performed independently.

**Video**
Link to video demonstrating:
-	Flex & Bison execution
-	Compilation process
-	Running the compiler on test files
[Add YouTube link here]

**Project Files Link**
Link to full project files (GitHub):
[Add link here]


