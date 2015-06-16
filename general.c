/******************************************************************************
 *  CVS version:
 *     $Id: general.c,v 1.1 2004/05/05 22:00:08 nickie Exp $
 ******************************************************************************
 *
 *  C code file : general.c
 *  Project     : PCL Compiler
 *  Version     : 1.0 alpha
 *  Written by  : Nikolaos S. Papaspyrou (nickie@softlab.ntua.gr)
 *  Date        : May 5, 2004
 *  Description : Generic symbol table in C, general variables and functions
 *
 *  Comments: (in Greek iso-8859-7)
 *  ---------
 *  Εθνικό Μετσόβιο Πολυτεχνείο.
 *  Σχολή Ηλεκτρολόγων Μηχανικών και Μηχανικών Υπολογιστών.
 *  Τομέας Τεχνολογίας Πληροφορικής και Υπολογιστών.
 *  Εργαστήριο Τεχνολογίας Λογισμικού
 */


/* ---------------------------------------------------------------------
   ---------------------------- Header files ---------------------------
   --------------------------------------------------------------------- */

#include <stdlib.h>
#include "symbol.h"
#include "general.h"
#include "error.h"


/* ---------------------------------------------------------------------
   ----------- Υλοποίηση των συναρτήσεων διαχείρισης μνήμης ------------
   --------------------------------------------------------------------- */

void * new (size_t size)
{
   void * result = malloc(size);
   
   if (result == NULL)
      fatal("\rOut of memory");
   return result;
}

void delete (void * p)
{
   if (p != NULL)
      free(p);
}

void insertLibraryFunctions() {
	SymbolEntry * temp = NULL;
	temp = newFunction("puti");
	openScope();
	newParameter("n", typeInteger, PASS_BY_VALUE, temp);
	endFunctionHeader(temp, typeVoid);
	closeScope();

	temp = newFunction("putb");
	openScope();
	newParameter("b", typeBoolean, PASS_BY_VALUE, temp);
	endFunctionHeader(temp, typeVoid);
	closeScope();

	temp = newFunction("putc");
	openScope();
	newParameter("c", typeChar, PASS_BY_VALUE, temp);
	endFunctionHeader(temp, typeVoid);
	closeScope();

	temp = newFunction("puts");
	openScope();
	newParameter("s", typeArray(0, typeChar), PASS_BY_VALUE, temp);
	endFunctionHeader(temp, typeVoid);
	closeScope();

	temp = newFunction("geti");
	openScope();
	endFunctionHeader(temp, typeInteger);
	closeScope();

	temp = newFunction("getb");
	openScope();
	endFunctionHeader(temp, typeBoolean);
	closeScope();

	temp = newFunction("getc");
	openScope();
	endFunctionHeader(temp, typeChar);
	closeScope();

	temp = newFunction("gets");
	openScope();
	newParameter("n", typeInteger, PASS_BY_VALUE, temp);
	newParameter("s", typeArray(0, typeChar), PASS_BY_VALUE, temp);
	endFunctionHeader(temp, typeVoid);
	closeScope();

	temp = newFunction("abs");
	openScope();
	newParameter("n", typeInteger, PASS_BY_VALUE, temp);
	endFunctionHeader(temp, typeInteger);
	closeScope();

	temp = newFunction("ord");
	openScope();
	newParameter("c", typeChar, PASS_BY_VALUE, temp);
	endFunctionHeader(temp, typeInteger);
	closeScope();

	temp = newFunction("chr");
	openScope();
	newParameter("n", typeInteger, PASS_BY_VALUE, temp);
	endFunctionHeader(temp, typeChar);
	closeScope();

	temp = newFunction("strlen");
	openScope();
	newParameter("s", typeArray(0, typeChar), PASS_BY_VALUE, temp);
	endFunctionHeader(temp, typeInteger);
	closeScope();

	temp = newFunction("strcmp");
	openScope();
	newParameter("s1", typeArray(0, typeChar), PASS_BY_VALUE, temp);
	newParameter("s2", typeArray(0, typeChar), PASS_BY_VALUE, temp);
	endFunctionHeader(temp, typeInteger);
	closeScope();

	temp = newFunction("strcpy");
	openScope();
	newParameter("trg", typeArray(0, typeChar), PASS_BY_VALUE, temp);
	newParameter("src", typeArray(0, typeChar), PASS_BY_VALUE, temp);
	endFunctionHeader(temp, typeVoid);
	closeScope();

	temp = newFunction("strcat");
	openScope();
	newParameter("trg", typeArray(0, typeChar), PASS_BY_VALUE, temp);
	newParameter("src", typeArray(0, typeChar), PASS_BY_VALUE, temp);
	endFunctionHeader(temp, typeVoid);
	closeScope();

}

/* ---------------------------------------------------------------------
   ------- Αρχείο εισόδου του μεταγλωττιστή και αριθμός γραμμής --------
   --------------------------------------------------------------------- */

const char * filename = "stdin";
int linecount;
