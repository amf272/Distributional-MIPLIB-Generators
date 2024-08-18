To generate OTS, run make_lp_files_sharing.ipynb.

### Problem parameters:
#### Network size
Use ```network_names = ["Texas7k"]``` for large networks and ```network_names = ["WECC240"]``` for small networks.
#### Number of days in the simulation
The number of days is specified by the month and day for the start and the end. Example:
```
#start date of simulations
month_start = 6
day_start  = 5

#end date of simulations
month_end = 6
day_end =20 
```

#### Budget for undergrounding
To specify a range for the budget: 
```
Bs = 300.0:5.0:500.0
```
Note: need to make sure this is float.
The generator and data were kindly provided by Ryan Piansky (Georgia Tech), Alyssa Kody (NC State; NREL soon), and Prof. Daniel Molzahn (Georgia Tech). The generator is based on [ Pollack, Madeleine, et al. "Equitably allocating wildfire resilience investments for power grids: The curse of aggregation and vulnerability indices." arXiv preprint arXiv:2404.11520 (2024).](https://arxiv.org/abs/2404.11520)

