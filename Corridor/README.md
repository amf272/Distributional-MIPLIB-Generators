mirror of: https://computational-sustainability.cis.cornell.edu/projects/index.php

Citations 
```
@inproceedings{dilkina2010corlat,
  title={Solving connected subgraph problems in wildlife conservation},
  author={Dilkina, Bistra and Gomes, Carla P},
  booktitle={International Conference on Integration of Artificial Intelligence (AI) and Operations Research (OR) Techniques in Constraint Programming},
  pages={102--116},
  year={2010},
  organization={Springer}
}
```
```
@article{conrad2012subgraph,
  title={Wildlife corridors as a connected subgraph problem},
  author={Conrad, Jon M and Gomes, Carla P and van Hoeve, Willem-Jan and Sabharwal, Ashish and Suter, Jordan F},
  journal={Journal of Environmental Economics and Management},
  volume={63},
  number={1},
  pages={1--18},
  year={2012},
  publisher={Elsevier}
}
```
```
@inproceedings{gomes2008networks,
  title={Connections in networks: A hybrid approach},
  author={Gomes, Carla P and Van Hoeve, Willem-Jan and Sabharwal, Ashish},
  booktitle={Integration of AI and OR Techniques in Constraint Programming for Combinatorial Optimization Problems: 5th International Conference, CPAIOR 2008 Paris, France, May 20-23, 2008 Proceedings 5},
  pages={303--307},
  year={2008},
  organization={Springer}
}
```
```
@inproceedings{conrad2007hardness,
  title={Connections in networks: Hardness of feasibility versus optimality},
  author={Conrad, Jon and Gomes, Carla P and Van Hoeve, Willem-Jan and Sabharwal, Ashish and Suter, Jordan},
  booktitle={Integration of AI and OR Techniques in Constraint Programming for Combinatorial Optimization Problems: 4th International Conference, CPAIOR 2007, Brussels, Belgium, May 23-26, 2007. Proceedings 4},
  pages={16--28},
  year={2007},
  organization={Springer}
}
```
*****************************************************************************

"corGenerator" is a generator of instances of the 
Connected Subgraph Problem with Node Costs and Node Profits. 

The synthetic instances generated here exemplify the type of problems one
encounters when solving the Wildlife Corridor Design Problem.

The distribution contains a README file, source code in C, makefile, 
examples, and related papers.

Please cite one of the following papers:

[1] Solving Connected Subgraph Problems in Wildlife Conservation 
Bistra Dilkina, Carla P. Gomes 
CPAIOR-10: 7th International Conference on Integration of AI and OR Techniques in Constraint Programming for Combinatorial Optimization Problems, Bologna, Italy, June 2010. 

[2] Wildlife Corridors as a Connected Subgraph Problem 
Jon Conrad, Carla P. Gomes, Willem-Jan van Hoeve, Ashish Sabharwal, Jordan F. Suter 
JEEM: Journal of Environmental Economics and Management. Volume 63, Issue 1, pp 1�18, January 2012

[3] Connections in Networks: A Hybrid Approach 
Carla P. Gomes, Willem-Jan van Hoeve, Ashish Sabharwal 
CPAIOR-08. 5th International Conference on Integration of AI and OR Techniques in Constraint Programming for Combinatorial Optimization Problems, LNCS volume 5015, pp 303-307, Paris, France, May 2008.

[4] Connections in Networks: Hardness of Feasibility versus Optimality 
Jon Conrad, Carla P. Gomes, Willem-Jan van Hoeve, Ashish Sabharwal, Jordan Suter 
CPAIOR-07. 4th International Conference on Integration of AI and OR Techniques in Constraint Programming for Combinatorial Optimization Problems, LNCS volume 4510, pp 16-28, Brussels, Belgium, May 2007.

Download related benchmark dataset on Grizzly Bear Corridor Design at http://www.cis.cornell.edu/ics/datasets/grizzly-instances.zip 

Report bugs and propose modifications and enhancements to bistra@cs.cornell.edu and gomes@cs.cornell.edu

Also see http://www.cs.cornell.edu/~bistra/connectedsubgraph.htm.

Authors:
Bistra Dilkina   	<bistra@cs.cornell.edu>
Ashish Sabharwal   	<sabhar@cs.cornell.edu>
Carla Gomes   		<gomes@cs.cornell.edu>

*****************************************************************************

Specifically, the code generates square grid graphs (lattices) of a desired order,
where nodes are associated with costs and utilities, and some nodes are designated as terminals (reserves). 

The program generates ascii files of type ".cor" that encodes a corridor
instance using a special format (see COR_FileFormat.txt).

Compile corEncoder by simply typing "make"

******************************************************************************

Usage:

Usage1 : corEncoder lattice {2f+random R | random R} {uncorrelated | weak} ORDER L D OUTFILE ReserveFree [SEED]
Usage2 : corEncoder graph GRAPHFILE {reserve RESERVEFILE | random R} {uncorrelated | weak} L D OUTFILE ReserveFree [SEED]

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

----------
Usage2 : corEncoder graph GRAPHFILE {reserve RESERVEFILE | random R} {uncorrelated | weak} L D OUTFILE ReserveFree [SEED]

GRAPHFILE is a graph/network file in GML format that specifies the nodes and edges
{reserve RESERVEFILE | random R} one of these parameters has to be selected:
RESERVEFILE is a text file that specifies the nodes that are to be treated as reserves (indexed 0 to N-1)

******************************************************************************

Example of generating an instance:

./corGenerator lattice 2f+random 3 uncorrelated 10 100 100 cor-lat-2f+r-u-10-100-100-3 1

./corGenerator graph zachary.gml random 3 uncorrelated 100 100 cor-zachary-r-u-100-100-3 1


******************************************************************************

REPORTING BUGS

If you find a bug in the generator, please make sure to tell us about it!

Report bugs and propose modifications and enhancements to
bistra@cs.cornell.edu and gomes@cs.cornell.edu
