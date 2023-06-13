import numpy as np
import networkx as nx
import fire
import pulp
# import gurobipy as grb


def partition_edges(edges, alpha, seed=1):
    np.random.seed(seed)
    E1 = set()
    E2 = set()
    for e in edges:
        if np.random.rand() <= alpha:
            E2.add(e)
        else:
            E1.add(e)
    return E1, E2


def generate_MIP(nodes, E1, E2, node_weight, edge_cost):

    # m = grb.Model()
    # node_vars = {i: m.addVar(obj=-node_weight, vtype=grb.GRB.BINARY)
    #              for i in nodes}

    # edge_vars = {(i, j): m.addVar(obj=edge_cost, vtype=grb.GRB.BINARY)
    #              for (i, j) in E2}

    # m.setAttr("modelSense", grb.GRB.MINIMIZE)
    # m.update()
    # for (i, j) in E1:
    #     m.addConstr(node_vars[i]+node_vars[j], grb.GRB.LESS_EQUAL, 1)
    # for (i, j) in E2:
    #     m.addConstr(node_vars[i]+node_vars[j] -
    #                 edge_vars[(i, j)], grb.GRB.LESS_EQUAL, 1)

    # m.update()

    # perform the above by pulp
    prob = pulp.LpProblem("GISP", pulp.LpMinimize)
    node_vars = {i: pulp.LpVariable("node_{}".format(i), cat=pulp.LpBinary)
                    for i in nodes}
    edge_vars = {(i, j): pulp.LpVariable("edge_{}_{}".format(i, j), cat=pulp.LpBinary)
                    for (i, j) in E2}
    prob += pulp.lpSum([-node_weight*node_vars[i] for i in nodes]) + pulp.lpSum([edge_cost*edge_vars[(i, j)] for (i, j) in E2])
    for (i, j) in E1:
        prob += node_vars[i]+node_vars[j] <= 1
    for (i, j) in E2:
        prob += node_vars[i]+node_vars[j]-edge_vars[(i, j)] <= 1

    return prob


def generate(filename, seed=1, nodes=75, edge_prob=0.5, edge_cost=1, node_weight=100, alpha=0.75):
    """
    Generate a generalized independent set instance


    Saves it as a CPLEX LP file.

    Parameters
    ----------
    filename : str
        Path to the file to save.
    """

    rng = np.random.RandomState(seed)
    graph_seed = rng.randint(2**31)
    # generate graph (or collect from dimacs)
    graph = nx.erdos_renyi_graph(nodes, edge_prob, seed=graph_seed)

    # generate mip
    partiton_seed = rng.randint(2**31)
    E1, E2 = partition_edges(graph.edges, alpha, partiton_seed)
    problem = generate_MIP(graph.nodes, E1, E2, node_weight, edge_cost)
    problem.writeMPS(filename)


if __name__ == "__main__":
    """
    python -m gisp --filename=test.mps
    """
    fire.Fire(generate)
