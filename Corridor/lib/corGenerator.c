/* Authors:
Bistra Dilkina   	<bistra@cs.cornell.edu>
Ashish Sabharwal   	<sabhar@cs.cornell.edu>
Carla Gomes   		<gomes@cs.cornell.edu>
*/

/*
This program generates random instances for the Wildlife Corridor Design problem,
a.k.a. the Connected Sugraph Problem with Node Costs and Node Profits.

Specifically, it generates square grid graphs (lattices) of a desired order,
where nodes are associated with costs and utilities, and some nodes are designated as terminals (reserves). 

The program generates ascii files of type ".cor" that encodes a corridor
instance using a special format (see function writeCorFile()).

Please cite one of the following papers:
[1] Solving Connected Subgraph Problems in Wildlife Conservation 
Bistra Dilkina, Carla P. Gomes 
CPAIOR-10: 7th International Conference on Integration of AI and OR Techniques in Constraint Programming for Combinatorial Optimization Problems, Bologna, Italy, June 2010. 

[2] Wildlife Corridors as a Connected Subgraph Problem 
Jon Conrad, Carla P. Gomes, Willem-Jan van Hoeve, Ashish Sabharwal, Jordan F. Suter 
JEEM: Journal of Environmental Economics and Management. Volume 63, Issue 1, pp 1–18, January 2012

[3] Connections in Networks: A Hybrid Approach 
Carla P. Gomes, Willem-Jan van Hoeve, Ashish Sabharwal 
CPAIOR-08. 5th International Conference on Integration of AI and OR Techniques in Constraint Programming for Combinatorial Optimization Problems, LNCS volume 5015, pp 303-307, Paris, France, May 2008.

[4] Connections in Networks: Hardness of Feasibility versus Optimality 
Jon Conrad, Carla P. Gomes, Willem-Jan van Hoeve, Ashish Sabharwal, Jordan Suter 
CPAIOR-07. 4th International Conference on Integration of AI and OR Techniques in Constraint Programming for Combinatorial Optimization Problems, LNCS volume 4510, pp 16-28, Brussels, Belgium, May 2007.

Also see http://www.cs.cornell.edu/~bistra/connectedsubgraph.htm.
Report bugs and propose modifications and enhancements to bistra@cs.cornell.edu.

The generator allows for the specification of several parameters.
It also allows for using an arbitrary network specified in the GML format, and generates the reserves, costs and utilities.
http://www.fim.uni-passau.de/en/fim/faculty/chairs/theoretische-informatik/projects.html (GML project documentation)
http://www-personal.umich.edu/~mejn/netdata/ (Datasets from Mark Newman)
http://www-personal.umich.edu/~mejn/netdata/readgml.zip (We use C package for reading GML provided by Mark Newman)

The input is specified in the command line (see below); there are
several options for the output (also specified in the command line),
namely the generation of a file of type "cor" that produces a corridor
instance using a special format (see function writeCorFile() and  readCorFile()).

Supports the option "lattice" for generating  cor instance on a square grid graph of a specified order.
Supports the option "graph" for generating  cor instance from a pre-specified graph in GML format (arbitrary graph).

Usage1 : corEncoder lattice {2f+random R | random R} {uncorrelated | weak} ORDER L D OUTFILE ReserveFree [SEED]
Usage2 : corEncoder graph GRAPHFILE {file RESERVEFILE | random R} {uncorrelated | weak} L D OUTFILE ReserveFree [SEED]

---------
Usage1 : corEncoder lattice {2f+random R | random R} {uncorrelated | weak} ORDER L D OUTFILE ReserveFree [SEED]

lattice - the corridor model is a set of ORDERxORDER cells arranged in a lattice;

{2f+random R| random R} one of these parameters has to be selected:
R is the number of reserves
2f+random - this model includes two fixed reserves, the upper left corner and the lower right corner, and the other reserves are picked randomly, R >= 2;
random - in this model, all the reserves are selected randomly;

{uncorrelated | weak} - one of these parameters has to be selected:
uncorrelated - the utilities and costs are generated independently and uniformly from the corresponding intervals: [1, L] and [1, D]
weak - the utility interval is weakly correlated with the cost interval; the utility interval for each node j is computed as: [c_j - D; c_j + D]
			
ORDER is the order of the lattice
L is the upper bound for the cost interval per parcel, each cost c_j is picked from [1,L];
D is the amplitude for the utility interval per parcel, each utiltiy u_j is picked from [c_j - D; c_j + D] when "weak" is selected, and from [1,D] when "uncorelated" is selected;
OUTFILE is the name of the output file (without extension);
ReserveFree is either 0 or 1; 1 meaning that reserve node cost is assigned to be 0
[SEED] is an optional argument. If provided, the random number generator is initialized with SEED.

-----------------------------------
Usage2 : corEncoder graph GRAPHFILE {file RESERVEFILE | random R} {uncorrelated | weak} L D OUTFILE ReserveFree [SEED]

GRAPHFILE is a graph/network file in GML format that specifies the nodes and edges
{file RESERVEFILE | random R} one of these parameters has to be selected:
RESERVEFILE is a text file that specifies the nodes that are to be treated as reserves (indexed 0 to N-1)

-----------------------------------

Example of generating an instance:

./corGenerator lattice 2f+random 3 uncorrelated 10 100 100 cor-lat-2f+r-u-10-100-100-3 1

./corGenerator graph zachary.gml random 3 uncorrelated 100 100 cor-zachary-r-u-100-100-3 1


*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "readgml.h"
#ifndef NT
#include <sys/times.h>
#include <sys/time.h>
#endif
#ifdef NT
#define random() rand()
#define srandom(seed) srand(seed)
#endif
#ifndef CLK_TCK
#define CLK_TCK 60
#endif

#define MAX_LINE_LENGTH 10000
#define MAX_NAME_LENGTH 10000

char* version = "Oct10-2012";

char linebuf[MAX_LINE_LENGTH+1];
char stringbuf[MAX_LINE_LENGTH+1];
char MyLinebuf[MAX_LINE_LENGTH+1];
char MyStringbuf[MAX_LINE_LENGTH+1];


/******************************************************************************/

int Order = 0; 	/* global variable for order of lattice */
int N = 0; 	/* global variable for number of parcels */
int L = 0;	/* global variable for cost interval [1,l] */
int D = 0; 	/* global variable for utility interval [cj-d, cj+d] */
int ReserveFree = 1; /* 1 - reserves are free */
int R = 2; /*total  number of reserves inclduing fixed if applicable */
int Corr =0; /* correlation - 0 uncorrelated ; 1 weak; */
int *Cost;	/* cost[i] holds cost of parcel i */
int *Util;	/* utility[i] holds utility of parcel i */
int *Res;	/* res[i] binary variable whether  parcel is a reserve */
int *NumNei;	/* NumNei[i] holds number of neighbors of parcel i */
int *Status;	/* Status[i] status of node in dfs */
int *Id;	/* Id[i] holds id of parcel i */
int **Neighbors;  /* neighbors[i][j] == neighbor j of parcel i; */
unsigned long Seed;
char     randomModel[MAX_NAME_LENGTH];
char     correlation[MAX_NAME_LENGTH];

char* execname;
/******************************************************************************/


/* ADD FORWARD DECLARATIONS OF ALL FUNCTIONS HERE! */
int allocCost(void);
int allocStatus(void);
int allocUtil(void);
int allocRes(void);
int allocNumNei();
int allocId();
int allocNeighbors(void);
int checkNeighbors(int* NumNei, int ** Neighbors);
int dfs(int curr, int* Id,  int* Status, int* NumNei, int** Neighbors);
int dfsTop(int* Id, int* Status, int* NumNei, int** Neighbors);
int error(char*);
unsigned long getSeed(void);
int populateValues(char*);
int setRandomReserves(char*);

int readCorFile(char *infile);
int writeCor(char *outfile,int argc, char *argv[]);
void readGraph(FILE *graphfile);
int writeCorFromGraph(char *outfile,int argc, char *argv[]);


void print_usage( char *execname){
		printf("This is corEncoder version %s\n\n", version);

		printf("Usage1 : %s lattice {2f+random R| random R} {uncorrelated | weak} ORDER L D OUTFILE ReserveFree [SEED] \n\n\n", execname);
		printf("Where:\n\nlattice - the corridor model is a set of ");
		printf("ORDERxORDER nodes arranged in a lattice;\n{2f+random | random } ");
		printf("one of these parameters has to be selected:\n ");
		printf("2f+random - this model includes two fixed reserves, the upper left corner and the lower right corner, and additional reserves are picked randomly;\n  ");
		printf("random - in this model, all the reserves are selected randomly; \n");
		printf("R is the number of reserves, including the 2 fixed ones if  2f+random is selected;\n");
		printf("{uncorrelated | weak} - one of these parameters; ");
			printf("if uncorrelated, the utilities and costs are generated independently and uniformly from the corresponding intervals: [1, L] and [1, D]; ");
			printf("if weak, the utility interval is weakly correlated with the cost  interval; ");
			printf("the utility interval is computed as: [c_j - D; c_j + D]; \n");
		printf("ORDER is the order of the lattice \n");
		printf("L is the upper bound for the cost  interval per parcel,c_j, [1,L];\n");
		printf("D is the amplitude for the  utility interval per parcel, [1,D] or  [c_j - D; c_j + D], depending on whether the correlation is uncorrelated or weak; \n");
		printf("OUTFILE is the name of the output file (without extension);\n");
		printf("ReserveFree is either 0 or 1; 1 meaning that reserve node cost is assigned to be 0; \n");
		printf("[SEED] is an optional argument. if provided, the random number generator is initialized with SEED. \n\n");

		printf("Usage2 : %s graph GRAPHFILE {file RESERVEFILE | random R}{uncorrelated | weak} L D OUTFILE ReserveFree [SEED]\n",execname);
		printf("Where:\n GRAPHFILE - is a file describing a network in GML format\n ");
		printf("\n either a file listing the reserve nodes is specified by 'file RESERVEFILE' or R reserves are selected at random using 'random R' \n");
		printf("\n R {uncorrelated|weak} L D OUTFILE ReserveFree [SEED] have same meaning as above  \n");
}

int main(int argc, char *argv[])
{
	int      i;
	char     command[MAX_NAME_LENGTH];
	char     infile[MAX_NAME_LENGTH];
	char     solfile[MAX_NAME_LENGTH];
	char     selfile[MAX_NAME_LENGTH];
	char     outfile[MAX_NAME_LENGTH];
	char     GRAPHFILE[MAX_NAME_LENGTH];

	FILE *fp;
	
	execname = argv[0];
	if (argc <= 1 || (strcmp(argv[1], "-h") == 0)) {
		print_usage(execname);
		exit(-1);
	}

	sscanf(argv[1], "%s", command);
	if (strcmp(command, "graph") == 0) {
		// Usage : corEncoder graph GRAPHFILE {file RESERVEFILE | random R}{uncorrelated | weak} ReserveFree NumParcels L D ANum ADen OUTFILE cor [SEED]
		if (argc < 10) error("Bad arguments to graph");
		char     RESERVEFILE[MAX_NAME_LENGTH];

		sscanf(argv[2], "%s", GRAPHFILE); // graphfile
		sscanf(argv[3], "%s", randomModel); // reserve or random
		if (strcmp(randomModel, "file")==0)
			sscanf(argv[4], "%s", RESERVEFILE);
		else if(strcmp(randomModel, "random")==0)
			sscanf(argv[4], "%d", &R);
		else
		{
			printf( "expected 'file' or 'random' but recieved: %s ", randomModel);
			error("wrong model.");
		}
		sscanf(argv[5], "%s", correlation);
		sscanf(argv[6], "%d", &L);
		sscanf(argv[7], "%d", &D);
		sscanf(argv[8], "%s", outfile);
		sscanf(argv[9], "%d", &ReserveFree);
		if (argc > 10)
			sscanf(argv[10], "%lu", &Seed);
		else
			Seed = getSeed();
		srandom(Seed);

		if ((strcmp(correlation, "uncorrelated")==0)){
			Corr = 0;
			if (D==0){
				printf( "D = %d ", D);
				error("for the uncorrelated model, D>1.");
			}
		}else if ((strcmp(correlation, "weak")==0))
		{ Corr = 1;}
		else{
			printf( "%s ", correlation);
			error("wrong correlation value.");
		}


		fprintf(stderr,"read in args\n");
		// read in parcel graph

		fp = fopen(GRAPHFILE, "r");
		if (fp == NULL) error((char*)"GRAPHFILE failed to open\n");
		fprintf(stderr,"readGraph\n");
		readGraph(fp); // sets N

		if (strcmp(randomModel, "file")==0){
			// read in reserves
			int nodeid;
			R=0;
			fprintf(stderr,"read Reserves\n");
			fp = fopen(RESERVEFILE, "r");
			if (fp == NULL) error((char*)"RESERVEFILE failed to open file\n");
			while(fscanf(fp, "%d",&nodeid) != 1){
				if(nodeid <0 || nodeid >= N){
					printf("Reserve id %d. ", nodeid);
					 error((char*)"Reserve id out of bounds[0,N)\n");
				}
				R++;
			}
			fclose(fp);
			allocRes();
			fp = fopen(RESERVEFILE, "r");
			while(fscanf(fp, "%d", &nodeid) != 0){
				Res[nodeid] = 1;
			}
			fclose(fp);
		}else if(strcmp(randomModel, "random")==0){
			allocRes();
			fprintf(stderr,"alloc Reserves\n");
		}

		allocCost();
		allocUtil();

		populateValues(randomModel);

		writeCorFromGraph(outfile,argc,argv);
	}else if (strcmp(command, "lattice") == 0) {
		if (argc < 10) error("Bad arguments to lattice");
		sscanf(argv[2], "%s", randomModel);
		sscanf(argv[3], "%d", &R);
		sscanf(argv[4], "%s", correlation);
		sscanf(argv[5], "%d", &Order);
		sscanf(argv[6], "%d", &L);
		sscanf(argv[7], "%d", &D);
		sscanf(argv[8], "%s", outfile);
		sscanf(argv[9], "%d", &ReserveFree);
		if (argc > 10)
			sscanf(argv[10], "%lu", &Seed);
		else
			Seed = getSeed();
		srandom(Seed);

		N = Order *Order;

		if ((strcmp(randomModel, "2f+random")==0) ||
			(strcmp(randomModel, "random")==0)){
				//ok
		}
		else{
			printf( "%s ", randomModel);
			error("wrong model.");
		}

		if ((strcmp(correlation, "uncorrelated")==0)){ 
			Corr = 0;
			if (D==0){
				printf( "D = %d ", D);
				error("for the uncorrelated model, D>=1.");
			}
		}else if ((strcmp(correlation, "weak")==0)){ 
			Corr = 1;
		}else{
			printf( "%s ", correlation);
			error("wrong correlation value.");
		}


		if ((strcmp(randomModel, "2f+random")==0) &&
			(R<2 || R > (Order*Order-2)  )) {
				error("wrong value for R; Pick R such that 2 <= R < Order*Order-2.");
		}
		if ((strcmp(randomModel, "random")==0) && (R > (Order*Order) || R <0)  ) {
			error("wrong value for R; Pick R such that 0 <= R < Order*Order.");
		}

	Cost = (int *)malloc(sizeof(int) * N);
	Util = (int *)malloc(sizeof(int) * N);
		allocCost();
		allocUtil();
		allocRes();

		populateValues(randomModel);
		
		writeCor(outfile,argc,argv);

	}else error("Bad option");
}



int allocCost(void)
{
	Cost = (int *)malloc(sizeof(int) * N);
	return(0);
}



int allocStatus(void)
{

	Status = (int *)malloc(sizeof(int) * N);
	return(0);
}


int allocNumNei(void)
{

	NumNei = (int *)malloc(sizeof(int) * N);
	return(0);
}


int allocNeighbors(void)
{
	int i;
	Neighbors = (int **)malloc(sizeof(int *) * N);
	for (i = 0; i < N; i++) {
		Neighbors[i] = (int *)malloc(sizeof(int) * N);
	}
	return(0);
}

int allocId(void)
{

	Id = (int *)malloc(sizeof(int) * N);
	return(0);
}


int allocUtil(void)
{

	Util = (int *)malloc(sizeof(int) * N);
	return(0);
}
int allocRes(void)
{

	Res = (int *)malloc(sizeof(int) * N);
	return(0);
}



int error(char *message)
{
	printf("%s\n", message);
	exit(1);
}


unsigned long getSeed(void)
{
	struct timeval tv;
	struct timezone tzp;
	gettimeofday(&tv,&tzp);
	return (( tv.tv_sec & 0177 ) * 1000000) + tv.tv_usec;
}

int populateValues(char *randomModel){

	int i;
	int sign;
	// generate array of reserves, costs, and utilities

	for (i = 0; i < N; i++) {
		Res[i] = 0;
	}
	if (strcmp(randomModel, "2f+random")==0) {
			Res[0] = 1;
			Res[N-1] = 1;
	}

	if ((strcmp(randomModel, "random")==0) ||
		(strcmp(randomModel, "2f+random")==0 && R > 2)) {
			setRandomReserves(randomModel);
	}

	fprintf(stderr,"past generate reserves\n");

	///
	for (i = 0; i < N; i++) {
		if ( ReserveFree==1 && Res[i]==1) {
			Cost[i] =0;
		}else {
			Cost[i] = 1 + ( random() % L);
		}
		if (Corr==0) {
			Util[i] = 1 +  (random() % D);
		}else {
			sign = random() % 2;
			if (sign==1) // if random is 1 add
			{Util[i] = Cost[i]  + ( random() % (D +1));}
			else
			{Util[i] = Cost[i]  - ( random() % (D + 1));}
		}
	}

	fprintf(stderr,"past generate cost and utils\n");
	return 0;
}


int writeCor(char *outfile,int argc, char *argv[])
{

	char  corfilename[MAX_NAME_LENGTH];
	FILE  *fp;
	int   i, j;
	int sign;
	int resNum;

	strcpy(corfilename, outfile);
	strcat(corfilename, ".cor");

	fp = fopen(corfilename, "w");


	// Write to file
	fprintf(fp, "c command line =");
	for (i=0;i < argc;i++){
		fprintf(fp, " %s", argv[i]);
	}
	fprintf(fp, "\n");
	fprintf(fp, "c Seed = %lu\n",Seed);
	fprintf(fp, "c \n");
	fprintf(fp, "c Corridor instance\n");
	fprintf(fp, "c Format:\n");
	fprintf(fp, "c p n r\n");
	fprintf(fp, "c   n is the number of parcels, n is  an integer;\n");
	fprintf(fp, "c   r is the number of reserves, n is  an integer;\n");
	fprintf(fp, "c n i b u c e i1 i2 ...  ie\n");
	fprintf(fp, "c   i is the id number of the node, i is an integer; \n");
	fprintf(fp, "c   b whether the node is a reserve; b is 0 or 1; \n");
	fprintf(fp, "c   u is the utility of the node; u is an integer; \n");
	fprintf(fp, "c   c is the cost of the node; c is an integer; \n");
	fprintf(fp, "c   e is the number of neighboring nodes; e is an integer; \n");
	fprintf(fp, "c   ij is the id of neighbor node j (j=1,2, ... ,e) \n");
	fprintf(fp, "c  \n");
	fprintf(fp, "c \n");
	fprintf(fp, "c n = %d\n", Order*Order);
	fprintf(fp, "c r = %d\n", R);
	fprintf(fp, "c l = %d\n", L);
	fprintf(fp, "c d = %d\n", D);
	fprintf(fp, "c terminalmodel = %s\n", randomModel);
	fprintf(fp, "c utilmodel = %s\n", correlation);
	///
	for (i=0;i<Order*Order; i++){
		if (Res[i]==1){
			fprintf(fp, "c reserve %d\n", i);
		}
	}
	///
	fprintf(fp, "c \n");
	fprintf(fp, "c \n");

	fprintf(fp, "p %d %d\n", Order*Order, R);
	for (i = 0; i < Order; i++) {
		for (j = 0; j < Order; j++) {
			if (i==0) {

				// top row
				if (j==0) {
					// upper left corner
					fprintf(fp, "n %d %d %d %d %d %d %d\n",i*Order+j,
						Res[i*Order+j], Util[i*Order+j],
						Cost[i*Order+j], 2, 1, Order);
				}else if (j == (Order-1)) {
					// upper right corner
					fprintf(fp, "n %d %d %d %d %d %d %d\n",i*Order+j,
						Res[i*Order+j], Util[i*Order+j],
						Cost[i*Order+j], 2, Order-2, 2*Order-1);
				}else
					// a non-corner cell of top row
					fprintf(fp, "n %d %d %d %d %d %d %d %d\n",i*Order+j,
					Res[i*Order+j], Util[i*Order+j],
					Cost[i*Order+j], 3, j-1, j+1, Order+j);
			}else if (i==Order-1) {
				// bottom row
				if (j==0) {
					// lower left corner
					fprintf(fp, "n %d %d %d %d %d %d %d\n",i*Order+j,
						Res[i*Order+j], Util[i*Order+j],
						Cost[i*Order+j], 2, (i-1)*Order+j, i*Order+j+1);
				}

				else if (j == (Order-1)) {
					// upper right corner
					fprintf(fp, "n %d %d %d %d %d %d %d\n",i*Order+j,
						Res[i*Order+j], Util[i*Order+j],
						Cost[i*Order+j], 2, (i-1)*Order+j, Order*Order-2);
				}
				else
					// a non-corner cell of bottom row
					fprintf(fp, "n %d %d %d %d %d %d %d %d\n",i*Order+j,
					Res[i*Order+j], Util[i*Order+j],
					Cost[i*Order+j], 3, (i-1)*Order+j, i*Order+j-1, i*Order+j+1);
			}else
				// a middle row
				if (j==0) {
					// left side
					fprintf(fp, "n %d %d %d %d %d %d %d %d\n",i*Order+j,
						Res[i*Order+j], Util[i*Order+j],
						Cost[i*Order+j], 3, (i-1)*Order+j, i*Order+j+1,
						(i+1)*Order+j);
				}
				else if (j==Order-1){
					//right side
					fprintf(fp, "n %d %d %d %d %d %d %d %d\n",i*Order+j,
						Res[i*Order+j], Util[i*Order+j],
						Cost[i*Order+j], 3, (i-1)*Order+j, i*Order+j-1,
						(i+1)*Order+j);
				}
				else {
					fprintf(fp, "n %d %d %d %d %d %d %d %d %d\n",i*Order+j,
						Res[i*Order+j], Util[i*Order+j],
						Cost[i*Order+j], 4, (i-1)*Order+j, i*Order+j-1,
						i*Order+j+1,(i+1)*Order+j);
				}
		}
	}
	fclose(fp);
	return(0);
}


int writeCorFromGraph(char *outfile,int argc, char *argv[])
{

	char  corfilename[MAX_NAME_LENGTH];
	FILE  *fp;
	int   i, j;
	strcpy(corfilename, outfile);
	strcat(corfilename, ".cor");

	fp = fopen(corfilename, "w");


	// Write to file
	fprintf(fp, "c command line =");
	for (i=0;i < argc;i++){
		fprintf(fp, " %s", argv[i]);
	}
	fprintf(fp, "\n");
	fprintf(fp, "c Seed = %lu\n",Seed);
	fprintf(fp, "c \n");
	fprintf(fp, "c Corridor instance\n");
	fprintf(fp, "c Format:\n");
	fprintf(fp, "c p n r\n");
	fprintf(fp, "c   n is the number of parcels, n is  an integer;\n");
	fprintf(fp, "c   r is the number of reserves, n is  an integer;\n");
	fprintf(fp, "c n i b u c e i1 i2 ...  ie\n");
	fprintf(fp, "c   i is the id number of the node, i is an integer; \n");
	fprintf(fp, "c   b whether the node is a reserve; b is 0 or 1; \n");
	fprintf(fp, "c   u is the utility of the node; u is an integer; \n");
	fprintf(fp, "c   c is the cost of the node; c is an integer; \n");
	fprintf(fp, "c   e is the number of neighboring nodes; e is an integer; \n");
	fprintf(fp, "c   ij is the id of neighbor node j (j=1,2, ... ,e) \n");
	fprintf(fp, "c  \n");
	fprintf(fp, "c \n");
	fprintf(fp, "c n = %d\n", N);
	fprintf(fp, "c r = %d\n", R);
	fprintf(fp, "c l = %d\n", L);
	fprintf(fp, "c d = %d\n", D);
	fprintf(fp, "c terminalmodel = %s\n", randomModel);
	fprintf(fp, "c utilmodel = %s\n", correlation);
	fflush(fp);
	///
	for (i=0;i<N; i++){
		if (Res[i]==1)
		{
			fprintf(fp, "c reserve %d\n", i);
		}
	}
	///
	fprintf(fp, "c \n");
	fprintf(fp, "c \n");

	fprintf(fp, "p %d %d\n", N, R);
	for (i = 0; i < N; i++) {
		fprintf(fp, "n %d %d %d %d %d ",i, Res[i], Util[i], Cost[i], NumNei[i]);
		for(j = 0; j < NumNei[i]; j++)
			fprintf(fp,"%d ", Neighbors[i][j]);
		fprintf(fp, "\n");
	}

	fclose(fp);

	return(0);
}


////////

int setRandomReserves(char* randomModel){

	int *array;
	int i;
	int resNum;
	int slack=0;
	int countOld=0;

	if ((strcmp(randomModel, "random")==0)){
		array = (int *)malloc(sizeof(int) * (N));
		for (i=0; i<N; i++) {
			array[i]= i;
		}
		for (i=0; i<R; i++) {
			resNum = random() % (N-i);
			Res[array[resNum]]=1;
			array[resNum]=array[N-(i+1)];
		}
	}else if ((strcmp(randomModel, "2f+random")==0)){
		array = (int *)malloc(sizeof(int) * (Order*Order-2));
		for (i=0; i<Order*Order-2; i++) {
			array[i]= i+1;
		}
		for (i=0; i<R-2; i++) {

			resNum = random() % (Order*Order-2-i);
			Res[array[resNum]]=1;
			array[resNum]=array[Order*Order-2-(i+1)];
		}
	}else{
		error("unknown random model.\n");
	}
	return(0);
}

int readCorFile(char *infile){
	char  corFile[MAX_NAME_LENGTH];
	FILE  *fp;
	int   i, j;
	int   n;
	int   r;
	int m;
	int id;
	int util;
	int cost;
	int nei;
	int res;
	char   first[1];
	char  rest[MAX_LINE_LENGTH];

	// read Corridor input file

	strcpy(corFile, infile);
	strcat(corFile, ".cor");
	fp = fopen(corFile, "r");
	if (fp == NULL) error((char*)"Read_cor_file failed to open file");

	fgets(MyLinebuf, MAX_LINE_LENGTH, fp);

	sscanf(MyLinebuf, "%s",first);

	while (strcmp(first, "p")!=0) {
		fgets(MyLinebuf, MAX_LINE_LENGTH, fp);
		sscanf(MyLinebuf, "%s",first);
	}
	sscanf(MyLinebuf,"p %d %d\n",&N,&R);
	//printf("n is %d;\nr is %d;\n",N,R);

	allocCost();
	allocStatus();
	allocUtil();
	allocRes();
	allocNumNei();
	allocId();
	allocNeighbors();

	int an;
	for (i=0; i<N; i++){
		fscanf(fp, "n %d %d %d %d %d",&id,&res,&util,&cost,&nei);
		Id[i]=id;
		Res[i]=res;


		Util[i]=util;
		Cost[i]=cost;
		NumNei[i]=nei;
		//      printf("n %d %d %d %d %d\n",id,res,util,cost,nei);
		if (nei>0){
			for (j=0; j<nei; j++){
				fscanf(fp, "%d",&an);
				Neighbors[i][j]=an;
				//printf("neighbor is %d\n", an);
			}
			fscanf(fp, "\n");
		}
	}
	checkNeighbors(NumNei, Neighbors);
	fclose(fp);
	return(0);
}


////



///


int  checkNeighbors(int* NumNei, int ** Neighbors){
	int i,j,k,m,nei;
	int flag=0;
	for (i=0; i< N; i++){
		for (j=0; j< NumNei[i]; j++){
			flag=0;
			nei = Neighbors[i][j];
			for(m=0;m<NumNei[nei];m++){
				if(Neighbors[nei][m]==i){
					flag=1;
					break;
				}
			}
			if (!flag) {
				printf("Could not find %d as a neighbor of %d\n", i, nei);
			}
		}
	}
}




int dfsTop(int* Id, int* Status, int* NumNei, int** Neighbors){

	int i;
	int numComp=0;

	// 2 - fully explored
	// 1 - discovered
	// 0 - undiscovered


	// set to 0 (undiscovered) the nodes that are part of the corridor

	for (i=0; i<N; i++){
		Status[i] = 0;
	}

	for (i=0; i< N; i++){
		if (Status[i]==0) {
			numComp++;
			printf("Component %d\n", numComp);
			dfs(i, Id, Status,NumNei, Neighbors);
			printf("\n\n");
		}
	}
	/* printf("Num Comp %d",numComp); */
	if (numComp > 1) {
		printf("ERROR ");
	}
	/*
	else
	printf("CORRECT - Num Comp=1\n");
	*/
	return(1);
}

int dfs(int curr, int* Id,  int* Status, int* NumNei, int** Neighbors){
	int i;
	int nei;
	//  cout << "DFS: Current Node " << curr << endl;
	Status[curr]= 1; // very important - so that it is not 0
	printf("%d ", curr);
	// so that it is not processed again
	for (i=0; i< NumNei[curr]; i++){
		nei = Neighbors[curr][i];
		if (Status[nei]==0) {
			dfs(nei, Id, Status, NumNei, Neighbors);
		}
	}
	Status[curr]=2;
	return(0);
}

////////////////////////////////
void readGraph(FILE *fp){
	NETWORK network;
	if(read_network(&network, fp)!= 0)
		error("Error reading graph file.");
	N = network.nvertices;
	//store data in local data structures
	allocNumNei();
	int i,j;
	Neighbors = (int **)malloc(sizeof(int *) * N);
	for (i = 0; i < N; i++) {
		NumNei[i] = network.vertex[i].degree;
		Neighbors[i] = (int *)malloc(sizeof(int) * NumNei[i] );
		for(j=0; j < network.vertex[i].degree; j++)
			Neighbors[i][j] = network.vertex[i].edge[j].target;
	}
	checkNeighbors(NumNei, Neighbors);
	fprintf(stderr, "read in neighbours\n");
	free_network(&network);
}



///////////////////////////////////
