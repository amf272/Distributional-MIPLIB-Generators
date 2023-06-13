corGenerator  = corGenerator

# ---------------------------------------------------------------------
# Compiler selection 
# ---------------------------------------------------------------------

CC  = gcc

# ---------------------------------------------------------------------
# Compiler options 
# ---------------------------------------------------------------------

COPT = -O3

$(corGenerator): $(corGenerator).o readgml.o
	$(CC) $(COPT) $(corGenerator).o readgml.o -o $(corGenerator)
$(corGenerator).o: $(corGenerator).c readgml.h
	$(CC) $(COPT) -o $(corGenerator).o -c $(corGenerator).c
readgml.o: readgml.c readgml.h network.h
	$(CC) $(COPT) -o readgml.o -c readgml.c

all: $(corGenerator)
compact:
	rm -f *.o

clean: compact
	rm -f $(corGenerator) 

