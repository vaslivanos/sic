%option noyywrap
%option nounput
%option noinput
%{
//#include "ast.h"
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include "symbol.h"
#include "sic.tab.h"
long long nestedcomments = 0;
long long linecnt = 1;
void yyerror( const char msg []);
%}

DIGIT 	([0-9])
UCHAR 	([A-Z])
LCHAR 	([a-z])
LETTER	([A-Za-z])
HEX		([0-9a-fA-F])
UNSCR 	([_])
QSTMRK	([?])
CHAR  	([a-zA-Z_?])
WHTSPC	([\t\r ])
NEWLINE	([\n])
DIGCHAR ([0-9a-zA-Z_?])
OPER	("+"|"-"|"*"|"/"|"#"|"="|"<"|">")
SEPAR	(","|";"|":"|"("|")"|"["|"]")
SNL		[^\\\'\"]

%x MULCOMMENT
%x COMMENT

%%

"and" 							{ return T_and; }
"bool"							{ return T_bool; }
"char"							{ return T_char; }
"decl" 							{ return T_decl; }
"def"							{ return T_def; }
"else"							{ return T_else; }
"elsif"							{ return T_elsif; }
"end"							{ return T_end; }
"exit"							{ return T_exit; }
"false"							{ return T_false; }
"for"							{ return T_for; }
"head"							{ return T_head; }
"if"							{ return T_if; }
"int"							{ return T_int; }
"list"							{ return T_list; }
"mod"							{ return T_mod; }
"new"							{ return T_new; }
"nil"							{ return T_nil; }
"nil?"							{ return T_nilqstn; }
"not"							{ return T_not; }
"or"							{ return T_or; }
"ref"							{ return T_ref; }
"return"						{ return T_return; }
"skip"							{ return T_skip; }
"tail"							{ return T_tail; }
"true"							{ return T_true; }
{LETTER}{DIGCHAR}*				{ yylval.n = (char *) malloc(sizeof(yytext)); strcpy(yylval.n, yytext); return T_id; }
{DIGIT}+						{ yylval.v.val = atoi(yytext); return T_number; }
{WHTSPC}						{ /* do nothing */ }
<INITIAL,MULCOMMENT>{NEWLINE}	{ linecnt++; }
"<*"							{ BEGIN(MULCOMMENT);
								  nestedcomments++; }
<MULCOMMENT>[^<*\n]*			{ /* do nothing */ }
<COMMENT>[^\n]*					{ /* do nothing */ }
"%"+[.]*						{ BEGIN(COMMENT); }
<COMMENT>{NEWLINE}				{ linecnt++;
								  BEGIN(INITIAL); }
<MULCOMMENT>"<*"				{ nestedcomments++; }
<MULCOMMENT>"*>"				{ nestedcomments--;
								  if(nestedcomments == 0)
								  	BEGIN(INITIAL); }
<MULCOMMENT>"<"+[^<*\n]*		{ /* do nothing */ }
<MULCOMMENT>"*"+[^>*\n]*		{ /* do nothing */ }
<INITIAL><<EOF>>				{ return 0; }
<MULCOMMENT><<EOF>>				{ yyerror("Multiline comment not terminated."); }
{OPER}|{SEPAR}					{ return yytext[0]; }
":="							{ return T_assign; }
"<>"							{ return T_ineq; }
"<="							{ return T_lthan; }
">="							{ return T_gthan; }
\"(\\.|[^\\"])*\"				{ yylval.v.name = (char *) malloc(sizeof(yytext)); strcpy(yylval.v.name, yytext); return T_string; }
\"(\\.|[^\\"])*{NEWLINE}		{ yyerror("String not terminated."); }
\'{SNL}\'						{ return T_character; }
\'\\\\\'						{ return T_backsls; }
\'\\"n"\'						{ return T_newline; }
\'\\"r"\'						{ return T_carret; }
\'\\"t"\'						{ return T_tab; }
\'\\"0"\'						{ return T_null; }
\'\\\'\'						{ return T_apostr; }
\'\\\"\'						{ return T_quote; }
\'\\"x"({HEX}{2})\'				{ return T_character; }

%%
