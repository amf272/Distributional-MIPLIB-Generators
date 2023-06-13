import shutil
import subprocess
import os
import sys
from lib.corMIPGen import parseCor, generateMIPInstance
import numpy as np
import glob
from collections import namedtuple

_largeint = 100000
_delete_old = True

CorlatExperiment = namedtuple("CorlatExperiment", ["exp_name", "seed",
                                                "num_graphs", "order", "num_reserves",
                                                "budget_fracs", "L", "D"])

script_path = os.path.dirname(sys.argv[0])

def genCorLattice(seed, out_prefix, corner_reserves=True, num_reserves=4, correlation="uncorrelated", order=20, L=100, D=100, reserve_free=True):
    
    # corlat instance generator is of the form:
    #       corGenerator lattice {2f+random R | random R} {uncorrelated | weak} ORDER L D OUTFILE ReserveFree [SEED]
    # build up params to feed to c++ corlat generator code
    corGenCmd = [os.path.join(script_path,"lib","corGenerator")]
    params = []
    params += ["lattice"]
    params += [("2f+" if corner_reserves else "")+"random", str(num_reserves)]
    params += [str(correlation)]
    params += [str(order)]
    params += [str(L)]
    params += [str(D)]
    outfile = out_prefix+"corlat_easy_"+("_".join(params)).replace(" ","_")+"_"+str(seed)
    params += [outfile]
    params += [str(seed)]
    corGenCmd += params
    output = subprocess.check_output(corGenCmd)

def genInstanceGrid(experiment):
    # generate instances according to an experiment distribution
    # for each seed
    # for each budget frac
    # generate a .cor file
    # once all cor files are generated, create instances varying the number of budget fractions
    # generate a .mps file from that
    np.random.seed(experiment.seed) # used for test
    
    cor_dir = os.path.join(script_path,"instances",experiment.exp_name,"corInstances/")
    mip_dir = os.path.join(script_path,"instances",experiment.exp_name,"mipInstances/")

    seeds = np.random.randint(_largeint, size=experiment.num_graphs)
    if not os.path.exists(cor_dir):
        os.makedirs(cor_dir)
    elif _delete_old:
        shutil.rmtree(cor_dir)
        os.makedirs(cor_dir)
    if not os.path.exists(mip_dir):
        os.makedirs(mip_dir)
    elif _delete_old:
        shutil.rmtree(mip_dir)
        os.makedirs(mip_dir)

    for seed in seeds:
        genCorLattice(seed, cor_dir, corner_reserves=True, num_reserves=experiment.num_reserves, correlation="uncorrelated", order=experiment.order, L=experiment.L, D=experiment.D, reserve_free=True)
    
    for cor_instance in glob.glob(os.path.join(cor_dir,"*.cor")):
        graph_data = parseCor(cor_instance)
        for budget_frac in experiment.budget_fracs:
            mip_instance = os.path.join(mip_dir, os.path.splitext(os.path.basename(cor_instance))[0]+"_{}.mps".format(budget_frac))
            model = generateMIPInstance(graph_data, budget_frac=budget_frac)
            model.write(mip_instance)


if __name__ == '__main__':
    exps = [
        CorlatExperiment(exp_name="corlat_o7", seed=1234,
            num_graphs=5,
            order=7,
            num_reserves=3,
            budget_fracs=[0.2,0.225,0.25,0.275,0.3],
            L=100,
            D=100),
        CorlatExperiment(exp_name="corlat_o8", seed=1234,
            num_graphs=3,
            order=8,
            num_reserves=3,
            budget_fracs=[0.2,0.225,0.25,0.275,0.3],
            L=100,
            D=100),
        CorlatExperiment(exp_name="corlat_o9", seed=1234,
            num_graphs=3,
            order=9,
            num_reserves=3,
            budget_fracs=[0.2,0.225,0.25,0.275,0.3],
            L=100,
            D=100),
        ]
    for experiment in exps:
        genInstanceGrid(experiment)

