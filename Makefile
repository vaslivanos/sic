CC=gcc
CFLAGS=-std=gnu99 -Wall -g
LIBS=libtony

sic : sic.lex.c sic.tab.c sic.tab.h sic.lex.o sic.tab.o symbol.o error.o general.o
	$(CC) $(CFLAGS) -o sic sic.tab.o sic.lex.o symbol.o error.o general.o

sic.lex.o sic.tab.o : sic.lex.c sic.tab.c sic.tab.h
	$(CC) $(CFLAGS) -c sic.lex.c sic.tab.c

symbol.o : symbol.c symbol.h
	$(CC) $(CFLAGS) -c symbol.c

error.o : error.c error.h
	$(CC) $(CFLAGS) -c error.c

general.o : general.c general.h
	$(CC) $(CFLAGS) -c general.c

sic.tab.c sic.tab.h : sic.y
	bison -dv sic.y

sic.lex.c : sic.l sic.tab.h
	flex -it sic.l > sic.lex.c

clean :
	$(RM) *.o sic.tab.c sic.tab.h sic.lex.c sic core sic.output
