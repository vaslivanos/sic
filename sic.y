%{
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include "error.h"
#include "general.h"
#include "symbol.h"

void yyerror(const char msg []);
void exitError();
int yylex();
extern long long linecnt;
bool error_flag = false;
bool eqTypeFlag = true;
long long errorcnt = 0;
int depth = 0;
int noBrackets = 0;
int paramNo[20];
char * onoma;
char * temp_string;
Type temp_type = NULL;
Type typo = NULL;
int temp_ref = 0;
int temp_par = 0;
SymbolEntry * curr_entr = NULL;
SymbolEntry * curr_id = NULL;
SymbolEntry * curr_par = NULL;
SymbolEntry * curr_fun[20];
SymbolEntry * curr_val = NULL;
SymbolEntry * temp_arr = NULL;
%}
%token T_and "and"
%token T_bool "bool"
%token T_char "char"
%token T_decl "decl"
%token T_def "def"
%token T_else "else"
%token T_elsif "elsif"
%token T_end "end"
%token T_exit "exit"
%token T_false "false"
%token T_for "for"
%token T_head "head"
%token T_if "if"
%token T_int "int"
%token T_list "list"
%token T_mod "mod"
%token T_new "new"
%token T_nil "nil"
%token T_nilqstn "nil?"
%token T_not "not"
%token T_or "or"
%token T_ref "ref"
%token T_return "return"
%token T_skip "skip"
%token T_tail "tail"
%token T_true "true"
%token T_assign T_ineq T_lthan T_gthan
%token<c> '(' ')' '+' '-' '*' '/' '#' '=' '<' '>' ',' ';' ':' '[' ']'
%token<c>T_backsls T_newline T_carret T_tab T_null T_apostr T_quote
%token<v> T_number
%token<v> T_string
%token<c> T_character
%token<n> T_id

%left T_or
%left T_and
%nonassoc T_not
%nonassoc '=' '<' '>' T_ineq T_lthan T_gthan
%right '#'
%left '+' '-'
%left '*' '/' T_mod
%right SIGNPLUS SIGNMINUS

%union {
	char * n;
	char c;
	int l;
	Type t;
	struct {
		Type type;		/* Type of non-terminal */
		bool ref;		/* True if the identifier is passed by reference and false if it is passed by value */
		bool par;		/* True if the identifier is a function parameter and false if it is a variable */
		int val;		/* The expression's integer value */
		bool newarr;	/* True if the non-terminal is a newly declared array, false otherwise */
		bool lvalue;	/* True if the non-terminal is an lvalue, false if it is a rvalue */
		char * name;	/* The non-terminal's name if it is an identifier */
	} v;
	//struct { List<quad> next; /* other fields */ } s;
}

%type<t> half_header opt_type type call
%type<v> opt_ref atom atom2 expr
%type<c> char_const
%type<l> brackets

%%

program			: { openScope(); insertLibraryFunctions(); } func_def { exitError(); }
				;

func_def 		: T_def header ':' func_def_list stmt_plus T_end { closeScope(); }
		 		;

header 			: half_header '(' parameters ')' { endFunctionHeader(curr_entr, $1); }
				;

half_header		: opt_type T_id
					{
						curr_entr = newFunction($2);
						openScope();
						$$ = $1;
					}
				;

opt_type		: type { $$ = $1; }
				| /* nothing */ { $$ = typeVoid; }
				;

parameters		: formal formal_list
				| /* nothing */
				;

formal			: opt_ref type T_id
					{
						if($1.ref == false)
							newParameter($3, $2, PASS_BY_VALUE, curr_entr);
						else
							newParameter($3, $2, PASS_BY_REFERENCE, curr_entr);
						temp_type = $2;
						temp_ref = $1.ref;
						temp_par = true;
					}
				  id_list
				;

opt_ref			: T_ref { $$.ref = true; }
				| /* nothing */ { $$.ref = false; }
				;

id_list			: ',' T_id
					{
						if(temp_par == true) {
							if(temp_ref == false)
								newParameter($2, temp_type, PASS_BY_VALUE, curr_entr);
							else
								newParameter($2, temp_type, PASS_BY_REFERENCE, curr_entr);
						}
						else if(temp_par == false) {
							newVariable($2, temp_type);
						}
					}
				  id_list
				| /* nothing */
				;

formal_list		: ';' formal formal_list
				| /* nothing */
				;

type			: T_int { $$ = typeInteger; }
				| T_bool { $$ = typeBoolean; }
				| T_char { $$ = typeChar; }
				| type '[' ']' { $$ = typeArray(0, $1); }
				| T_list '[' type ']' { $$ = typeList($3); }
				;

func_def_list	: func_def func_def_list
				| func_decl func_def_list
				| var_def func_def_list
				| /* nothing */ 
				;

func_decl		: T_decl header
					{
						forwardFunction(curr_entr);
					  	closeScope();
					}
				;

var_def			: type T_id
					{
						newVariable($2, $1);
						temp_par = false;
						temp_type = $1;
					}
				  id_list
				;

stmt_plus		: stmt stmt_plus
				| stmt
				;

stmt			: simple
				| T_exit
				| T_return expr
					{
						if(!equalType($2.type, curr_entr->u.eFunction.resultType)) {
							if($2.type->kind == TYPE_ARRAY && curr_entr->u.eFunction.resultType->kind == TYPE_ARRAY)
								if(equalType($2.type->refType, curr_entr->u.eFunction.resultType))
									break;
							if(curr_entr->u.eFunction.resultType->kind == TYPE_LIST && $2.type->kind == TYPE_LIST && $2.type->refType->kind == TYPE_VOID)
								break;
							errorcnt++;
							errorcnt++;
							yyerror("Type mismatch: Return type differs from function type.");
						}
					}
				| T_if expr ':' stmt_plus elsif_list opt_else T_end
					{
						if($2.type->kind != TYPE_BOOLEAN) {
							errorcnt++;
							yyerror("Expression in 'if' statement is not of bool type.");
						}
					}
				| T_for simple_plus ';' expr ';' simple_plus ':' stmt_plus T_end
					{
						if($4.type->kind != TYPE_BOOLEAN) {
							errorcnt++;
							yyerror("Expression in 'for' statement is not of bool type.");
						}
					}
				;

simple			: T_skip
				| atom T_assign expr
					{
						if($1.lvalue == false) {
							errorcnt++;
							yyerror("Assignment to a string literal or function not permitted.");
						}
						else if($3.newarr == true) {
							temp_arr = lookupEntry($1.name, LOOKUP_ALL_SCOPES, true);
							temp_arr->u.eVariable.type->size = $3.type->size;
							noBrackets--;
						}
						else
							noBrackets = 0;
						eqTypeFlag = true;
						typo = $1.type;
						while(noBrackets > 0) {
							typo = typo->refType;
							noBrackets--;
						}
						if(!(equalType(typo, $3.type))) {
							if(($3.newarr == true && typo->kind == TYPE_ARRAY && $3.type->kind == TYPE_ARRAY) && ((typo->refType->kind == $3.type->refType->kind) && typo->size == 0))
								break;
							if($3.type->kind == TYPE_LIST && $3.type->refType->kind == TYPE_VOID)
								break;
							/*printf("Line: %lld\n", linecnt);
							printType($1.type);
							printType($3.type);*/
							errorcnt++;
							yyerror("Invalid type in assignment.");
							eqTypeFlag = false;
						}
						if(eqTypeFlag == true) {
							curr_id = lookupEntry($1.name, LOOKUP_ALL_SCOPES, true);
							/*printf("Assignment Line 1: %lld\n", linecnt);
							printParameters(curr_entr);*/
							if(curr_id->entryType == ENTRY_PARAMETER)
								curr_id->u.eParameter.value.vInteger = $3.val;
							else if(curr_id->entryType == ENTRY_VARIABLE)
								curr_id->u.eVariable.value.vInteger = $3.val;
							else {
								errorcnt++;
								yyerror("Assignment l-value must be a variable or parameter.");
							}
							/*printf("Assignment Line 2: %lld\n", linecnt);
							printParameters(curr_entr);*/
						}
					}
				| call
				;

atom			: T_id
					{
						curr_id = lookupEntry($1, LOOKUP_ALL_SCOPES, true);
						$$.type = curr_id->u.eVariable.type;
						if(curr_id->u.eVariable.type->kind == TYPE_INTEGER) {
							if(curr_id->entryType == ENTRY_PARAMETER)
								$$.val = curr_id->u.eParameter.value.vInteger;
							else if(curr_id->entryType == ENTRY_VARIABLE)
								$$.val = curr_id->u.eVariable.value.vInteger;
							else {
								errorcnt++;
								yyerror("Assignment l-value must be a variable or parameter.");
							}
						}
						$$.lvalue = true;
						$$.name = $1;
					}
				| T_string
					{
						$$.lvalue = false;
						$$.name = $1.name;
						$$.type = typeArray(strlen($1.name), typeChar);
					}
				| atom2 '[' expr ']' brackets
					{
						if($3.type->kind != TYPE_INTEGER) {
							curr_id = lookupEntry($3.name, LOOKUP_ALL_SCOPES, true);
							if(curr_id->u.eVariable.type->kind != TYPE_INTEGER) {
								errorcnt++;
								yyerror("Index of array is not of integer type.");
							}
						}
						//if($3.val > 0) {
						temp_type = $1.type->refType;
						noBrackets = $5;
						while(noBrackets > 0) {
							temp_type = temp_type->refType;
							noBrackets--;
						}
						$$.type = temp_type;
						$$.name = $1.name;
						$$.lvalue = true;
						/*printf("Line: %lld\n", linecnt);
						printf("%s\n", $$.name);
						printType($1.type);
						printType($$.type);
						if($$.type == NULL) {
							printf("Gameisai\n");
							exit(1);
						}*/
						noBrackets = $5 + 1;
						/*}
						else {
							errorcnt++;
							yyerror("Array size negative or zero.");
						}*/
						/*printf("Found sth! %lld\n", linecnt);
						fflush(stdout);*/
					}
				| call
					{
						$$.type = $1;
						$$.lvalue = false;
					}
				;

atom2			: T_id
					{
						curr_id = lookupEntry($1, LOOKUP_ALL_SCOPES, true);
						$$.type = curr_id->u.eVariable.type;
						if(curr_id->u.eVariable.type->kind == TYPE_INTEGER) {
							if(curr_id->entryType == ENTRY_PARAMETER)
								$$.val = curr_id->u.eParameter.value.vInteger;
							else if(curr_id->entryType == ENTRY_VARIABLE)
								$$.val = curr_id->u.eVariable.value.vInteger;
							else {
								errorcnt++;
								yyerror("Assignment l-value must be a variable or parameter.");
							}
						}
						$$.lvalue = true;
						$$.name = $1;
						/*printf("Atom2: Name: %s\n", $$.name);
						printf("Atom2: Type: ");
						printType($$.type);*/
					}
				| call
					{
						$$.type = $1;
						$$.lvalue = false;
					}
				;

brackets		: '[' expr ']' brackets
					{
						if($2.type->kind != TYPE_INTEGER) {
							curr_id = lookupEntry($2.name, LOOKUP_ALL_SCOPES, true);
							if(curr_id->u.eVariable.type->kind != TYPE_INTEGER) {
								errorcnt++;
								yyerror("Index of array is not of integer type.");
							}
						}
						$$ = $4 + 1;
					}
				| /* nothing */ { $$ = 0; }
				;

call			: T_id
					{
						depth++;
						if(depth >= 20) {
							errorcnt++;
							yyerror("Too many nested function calls.");
						}
						curr_fun[depth] = lookupEntry($1, LOOKUP_ALL_SCOPES, true);
						if(curr_fun[depth] != NULL && curr_fun[depth]->u.eFunction.firstArgument != NULL && getParameter(curr_fun[depth],1) == NULL) {
							errorcnt++;
							yyerror("Too many arguments in use of function.");
						}
					}
				  '(' opt_expr ')'
				  	{
						$$ = curr_fun[depth]->u.eFunction.resultType;
						paramNo[depth] = 0;
						depth--;
						if(depth < 0) {
							errorcnt++;
							yyerror("Depth not handled well.");
						}
					}

				;

opt_expr		: expr
					{
						paramNo[depth]++;
						curr_par = getParameter(curr_fun[depth], paramNo[depth]);
						if(curr_par == NULL) {
							errorcnt++;
							yyerror("Too many arguments in use of function.");
						}
						/*printParameters(curr_fun[depth]);
						printType($1.type);
						printType(curr_par->u.eParameter.type);*/
						if(!equalType($1.type, curr_par->u.eParameter.type)) {
							if($1.type->kind == TYPE_ARRAY && curr_par->u.eParameter.type->kind == TYPE_ARRAY)
								if(equalType($1.type->refType, curr_par->u.eParameter.type))
									break;
							if(curr_par->u.eParameter.type->kind == TYPE_LIST && $1.type->kind == TYPE_LIST && $1.type->refType->kind == TYPE_VOID)
								break;
							errorcnt++;
							yyerror("Parameter type mismatch in function.");
						}
					}
				  expr_list
				| /* nothing */
				;

expr_list		: ','
					{
						curr_par = getParameter(curr_fun[depth], paramNo[depth]);
						if(curr_par == NULL) {
							errorcnt++;
							yyerror("Too many arguments in use of function.");
						}
					}
				  expr
					{
						paramNo[depth]++;
						curr_par = getParameter(curr_fun[depth], paramNo[depth]);
						if(curr_par == NULL) {
							errorcnt++;
							yyerror("Too many arguments in use of function.");
						}
						/*printParameters(curr_fun[depth]);
						printType($3.type);
						printType(curr_par->u.eParameter.type);*/
						if(!equalType($3.type, curr_par->u.eParameter.type)) {
							if($3.type->kind == TYPE_ARRAY && curr_par->u.eParameter.type->kind == TYPE_ARRAY)
								if(equalType($3.type->refType, curr_par->u.eParameter.type))
									break;
							if(curr_par->u.eParameter.type->kind == TYPE_LIST && $3.type->kind == TYPE_LIST && $3.type->refType->kind == TYPE_VOID)
								break;
							errorcnt++;
							yyerror("Parameter type mismatch in function.");
						}
					}
				  expr_list
				| /* nothing */
				;

expr			: atom
					{
						$$.type = $1.type;
						$$.name = $1.name;
					}
				| T_number
					{
						$$.type = typeInteger;
						$$.val = $1.val;
					}
				| char_const
					{
						$$.type = typeChar;
						temp_string = (char *) malloc(2*sizeof(char));
						sprintf(temp_string, "%c", $1);
						$$.name = temp_string;
					}
				| '(' expr ')'
					{
						$$.type = $2.type;
						$$.name = $2.name;
						$$.val = $2.val;
					}
				| '+' expr %prec SIGNPLUS
					{
						if($2.type->kind != TYPE_INTEGER) {
							errorcnt++;
							yyerror("Non-integer operand in '+' operator.");
						}
						$$.type = $2.type;
						$$.val = $2.val;
					}
				| '-' expr %prec SIGNMINUS
					{
						if($2.type->kind != TYPE_INTEGER) {
							errorcnt++;
							yyerror("Non-integer operand in '-' operator.");
						}
						$$.type = $2.type;
						$$.val = - $2.val;
					}
				| expr '+' expr
					{
						if($1.type->kind == TYPE_INTEGER && $3.type->kind == TYPE_INTEGER) {
							$$.type = typeInteger;
							$$.val = $1.val + $3.val;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Expected integer.");
						}
					}
				| expr '-' expr
					{
						if($1.type->kind == TYPE_INTEGER && $3.type->kind == TYPE_INTEGER) {
							$$.type = typeInteger;
							$$.val = $1.val - $3.val;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Expected integer.");
						}
					}
				| expr '*' expr
					{
						if($1.type->kind == TYPE_INTEGER && $3.type->kind == TYPE_INTEGER) {
							$$.type = typeInteger;
							$$.val = $1.val * $3.val;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Expected integer.");
						}
					}
				| expr '/' expr
					{
						if($1.type->kind == TYPE_INTEGER && $3.type->kind == TYPE_INTEGER) {
							$$.type = typeInteger;
							$$.val = $1.val / $3.val;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Expected integer.");
						}
					}
				| expr T_mod expr
					{
						if($1.type->kind == TYPE_INTEGER && $3.type->kind == TYPE_INTEGER) {
							$$.type = typeInteger;
							$$.val = $1.val % $3.val;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Expected integer.");
						}
					}
				| expr '=' expr
					{
						if(equalType($1.type, $3.type)) {
							$$.type = typeBoolean;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Comparison between expressions of different type.");
						}
					}
				| expr T_ineq expr
					{
						if(equalType($1.type, $3.type)) {
							$$.type = typeBoolean;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Comparison between expressions of different type.");
						}
					}
				| expr '<' expr
					{
						if(equalType($1.type, $3.type)) {
							$$.type = typeBoolean;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Comparison between expressions of different type.");
						}
					}
				| expr '>' expr
					{
						if(equalType($1.type, $3.type)) {
							$$.type = typeBoolean;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Comparison between expressions of different type.");
						}
					}
				| expr T_lthan expr
					{
						if(equalType($1.type, $3.type)) {
							$$.type = typeBoolean;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Comparison between expressions of different type.");
						}
					}
				| expr T_gthan expr
					{
						if(equalType($1.type, $3.type)) {
							$$.type = typeBoolean;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Comparison between expressions of different type.");
						}
					}
				| T_true
					{
						$$.type = typeBoolean;
					}
				| T_false
					{
						$$.type = typeBoolean;
					}
				| T_not expr
					{
						if($2.type->kind == TYPE_BOOLEAN) {
							$$.type = typeBoolean;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: 'not' operator used on non-boolean expression.");
						}
					}
				| expr T_and expr
					{
						if($1.type->kind == TYPE_BOOLEAN && $3.type->kind == TYPE_BOOLEAN) {
							$$.type = typeBoolean;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Expected boolean.");
						}
					}
				| expr T_or expr
					{
						if($1.type->kind == TYPE_BOOLEAN && $3.type->kind == TYPE_BOOLEAN) {
							$$.type = typeBoolean;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Expected boolean.");
						}
					}
				| T_new type '[' expr ']'
					{
						if($4.type->kind == TYPE_INTEGER) {
							//if($4.val > 0) {
								$$.type = typeArray($4.val, $2);
								//printf("Step 1: \n");
								//printType($$.type);
								$$.newarr = true;
							/*}
							else {
								errorcnt++;
								yyerror("Array size negative or zero.");
							}*/
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Expected integer.");
						}
					}
				| T_nil
					{
						$$.type = typeList(typeVoid);
						$$.type->size = 0;
					}
				| T_nilqstn '(' expr ')'
					{
						if($3.type->kind != TYPE_LIST) {
							errorcnt++;
							yyerror("Type mismatch: Expected list.");
						}
						else {
							$$.type = typeBoolean;
						}
					}
				| expr '#' expr
					{
						if($3.type->kind == TYPE_LIST && (equalType($3.type->refType, $1.type) || $3.type->refType->kind == TYPE_VOID)) {
							$$.type = $3.type;
							$$.type->size++;
							$$.type->refType = $1.type;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Concatenating lists of different types.");
						}
					}
				| T_head '(' expr ')'
					{
						if($3.type->kind == TYPE_LIST) {
							$$.type = $3.type->refType;
							$$.val = $3.val;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Cannot get 'head' of non-list.");
						}
					}
				| T_tail '(' expr ')'
					{
						if($3.type->kind == TYPE_LIST) {
							$$.type = $3.type;
						}
						else {
							errorcnt++;
							yyerror("Type mismatch: Cannot get 'tail' of non-list.");
						}
					}
				;

char_const		: T_character
				| T_backsls
				| T_newline
				| T_carret
				| T_tab
				| T_null
				| T_apostr
				| T_quote
				;

elsif_list		: T_elsif expr ':' stmt_plus elsif_list
					{
						if($2.type->kind != TYPE_BOOLEAN) {
							errorcnt++;
							yyerror("Expression in 'elsif' statement is not of bool type.");
						}
					}
				| /* nothing */
				;

opt_else		: T_else ':' stmt_plus
				| /* nothing */
				;

simple_plus		: simple simple_list
				;

simple_list		: ',' simple simple_list
				| /* nothing */
				;

%%
void yyerror(const char msg []) {
	error_flag = true;
	fprintf(stderr,"ERROR. Line %lld: %s\n",linecnt,msg);
}

void exitError() {
	if(error_flag == true) {
		fprintf(stderr, "sic: %lld errors encountered.\n", errorcnt);
		exit(1);
	}
}

int main() {
	initSymbolTable(SYM_TABLE_SIZE);
	int result = yyparse();
	destroySymbolTable();
	if(result != 0)
		return result;
	printf("Semantics analysis, OK.\n");
	return 0;
}
