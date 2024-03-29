%{
//**************************************
// lang.y
//
// Parser definition file. bison uses this file to generate the parser.
//
// Author: Phil Howard 
// phil.howard@oit.edu
//
// Date: Jan. 18, 2016
//
// Edited by: Jessica Maxey

#include <iostream>
using std::cout;
using std::endl;

#include "lex.h"
#include "astnodes.h"
#include <string>
using std::string;


%}

%locations

 /* union defines the type for lexical values */
%union{
    int             int_val;
    double          float_val;
    cAstNode*       ast_node;
    cProgramNode*   program_node;
    cBlockNode*     block_node;
    cStmtsNode*     stmts_node;
    cStmtNode*      stmt_node;
    cExprNode*      expr_node;
    cFuncDeclNode*  func_node;
    cFuncExprNode*  funccall_node;
    cSymbol*        symbol;
    cSymbolTable::symbolTable_t*  sym_table;
    cDeclsNode*     decls_node;
    cDeclNode*      decl_node;
    cVarExprNode*   varref_node;
    cParamListNode* params_node;
    }

%{
    int yyerror(const char *msg);
    void SemanticError(string error);

    cAstNode *yyast_root;
%}

%{
bool g_semanticErrorHappened = false;
#define CHECK_ERROR() { if (g_semanticErrorHappened) \
    { g_semanticErrorHappened = false; } }
#define PROP_ERROR() { if (g_semanticErrorHappened) \
    { g_semanticErrorHappened = false;  YYERROR; } }
%}

%start  program

%token <symbol>    IDENTIFIER
%token <symbol>    TYPE_ID
%token <int_val>   CHAR_VAL
%token <int_val>   INT_VAL
%token <float_val> FLOAT_VAL
%token <int_val>   AND
%token <int_val>   OR
%token <int_val>   EQUALS

%token  PRINT
%token  WHILE IF ELSE ENDIF
%token  STRUCT
%token  RETURN
%token  JUNK_TOKEN

%type <program_node> program
%type <block_node> block
%type <sym_table> open
%type <sym_table> close
%type <decls_node> decls
%type <decl_node> decl
%type <decl_node> var_decl
%type <decl_node> struct_decl
%type <func_node> func_decl
%type <func_node> func_header
%type <func_node> func_prefix
%type <funccall_node> func_call
%type <decls_node> paramsspec
%type <decl_node> paramspec
%type <stmts_node> stmts
%type <stmt_node> stmt
%type <varref_node> lval
%type <params_node> params
%type <expr_node> param
%type <expr_node> expr
%type <expr_node> addit
%type <expr_node> term
%type <expr_node> fact
%type <varref_node> varref
%type <symbol> varpart

%%

program: block                  { $$ = new cProgramNode($1);
                                  yyast_root = $$;
                                  if (yynerrs == 0) 
                                      YYACCEPT;
                                  else
                                      YYABORT;
                                }
block:  open decls stmts close  { $$ = new cBlockNode($2, $3); }
    |   open stmts close        { $$ = new cBlockNode(nullptr, $2); }

open:   '{'                     { $$ = g_SymbolTable.IncreaseScope(); }

close:  '}'                     { $$ = g_SymbolTable.DecreaseScope(); }

decls:      decls decl          { $$ = $1; $$->Insert($2); }
        |   decl                { $$ = new cDeclsNode($1); }
decl:       var_decl ';'        { $$ = $1; }
        |   struct_decl ';'     { $$ = $1; }
        |   func_decl           { $$ = $1; }
        |   error ';'           {}

var_decl:   TYPE_ID IDENTIFIER  { $$ = new cVarDeclNode($1, $2); CHECK_ERROR(); }
var_decl:   STRUCT IDENTIFIER IDENTIFIER  { $$ = new cVarDeclNode($2, $3); CHECK_ERROR();}
struct_decl:  STRUCT open decls close IDENTIFIER    
                                { $$ = new cStructDeclNode($2, $3, $5); }
func_decl:  func_header ';'
                                { $$ = $1;  
                                  g_SymbolTable.DecreaseScope();  
                                  CHECK_ERROR();
                                }
        |   func_header  '{' decls stmts '}'
                                { $$ = $1; 
                                  $$->AddDecls($3); 
                                  $$->AddStmts($4); 
                                  g_SymbolTable.DecreaseScope();  
                                  CHECK_ERROR();
                                }
        |   func_header  '{' stmts '}'
                                { $$ = $1; 
                                  $$->AddStmts($3); 
                                  g_SymbolTable.DecreaseScope();  
                                  CHECK_ERROR();
                                }
func_header: func_prefix paramsspec ')'
                                { 
                                  $$ = $1; 
                                  $$->AddParams($2); 
                                  CHECK_ERROR();
                                }
        |    func_prefix ')'    { 
                                  $$ = $1;
                                  $$->AddParams(nullptr);
                                  CHECK_ERROR(); 
                                }
func_prefix: TYPE_ID IDENTIFIER '('
                                { $$ = new cFuncDeclNode($1, $2); 
                                  g_SymbolTable.IncreaseScope();
                                  CHECK_ERROR(); 
                                }
paramsspec: paramsspec',' paramspec 
                                { $$ = $1; $$->Insert($3); }
        |   paramspec           { $$ = new cParamsNode($1); }

paramspec:  var_decl            { $$ = $1; }

stmts:      stmts stmt          { $$ = $1; $$->Insert($2); }
        |   stmt                { $$ = new cStmtsNode($1); }

stmt:       IF '(' expr ')' stmts ENDIF ';'
                                { $$ = new cIfNode($3, $5, nullptr); }
        |   IF '(' expr ')' stmts ELSE stmts ENDIF ';'
                                { $$ = new cIfNode($3, $5, $7); }
        |   WHILE '(' expr ')' stmt 
                                { $$ = new cWhileNode($3, $5); }
        |   PRINT '(' expr ')' ';'
                                { $$ = new cPrintNode($3); }
        |   lval '=' expr ';'   { $$ = new cAssignNode($1, $3); CHECK_ERROR(); }
        |   lval '=' func_call ';'   { $$ = new cAssignNode($1, $3); CHECK_ERROR();}
        |   func_call ';'       { $$ = $1; }
        |   block               { $$ = $1; }
        |   RETURN expr ';'     { $$ = new cReturnNode($2); }
        |   error ';'           {}

func_call:  IDENTIFIER '(' params ')' { $$ = new cFuncExprNode($1, $3); CHECK_ERROR(); }
        |   IDENTIFIER '(' ')'  { $$ = new cFuncExprNode($1, nullptr); CHECK_ERROR(); }

varref:   varref '.' varpart    { $$ = $1; $$->AddElement($3); PROP_ERROR(); }
        | varpart               { $$ = new cVarExprNode($1); PROP_ERROR(); }

varpart:  IDENTIFIER            { $$ = $1; }

lval:     varref                { $$ = $1; CHECK_ERROR(); }

params:     params',' param     { $$ = $1; $$->Insert($3); }
        |   param               { $$ = new cParamListNode($1); }

param:      expr                { $$ = $1; }

expr:       expr EQUALS addit   { $$ = new cBinaryExprNode($1, $2, $3); }
        |   addit               { $$ = $1; }

addit:      addit '+' term      { $$ = new cBinaryExprNode($1, '+', $3); }
        |   addit '-' term      { $$ = new cBinaryExprNode($1, '-', $3); }
        |   term                { $$ = $1; }

term:       term '*' fact       { $$ = new cBinaryExprNode($1, '*', $3); }
        |   term '/' fact       { $$ = new cBinaryExprNode($1, '/', $3); }
        |   term '%' fact       { $$ = new cBinaryExprNode($1, '%', $3); }
        |   fact                { $$ = $1; }

fact:        '(' expr ')'       { $$ = $2; }
        |   INT_VAL             { $$ = new cIntExprNode($1); }
        |   FLOAT_VAL           { $$ = new cFloatExprNode($1); }
        |   varref              { $$ = $1; PROP_ERROR(); }

%%

// Function to format error messages
int yyerror(const char *msg)
{
    std::cerr << "ERROR: " << msg << " at symbol "
        << yytext << " on line " << yylineno << "\n";

    return 0;
}

void SemanticError(string error)
{
    cout << "ERROR: " << error << " on line " << yylineno << "\n";
    g_semanticErrorHappened = true;
    yynerrs++;
}
