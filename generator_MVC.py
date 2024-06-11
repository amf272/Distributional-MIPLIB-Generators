import networkx as nx
import numpy as np
import random
import scipy.sparse
import pyscipopt
from pyscipopt import quicksum
import submitit
import pickle

def gen_graph(max_n, min_n, g_type='barabasi_albert', edge=4):
    cur_n = np.random.randint(max_n - min_n + 1) + min_n
    if g_type == 'erdos_renyi':
        g = nx.erdos_renyi_graph(n = cur_n, p = edge * 1.0 /  (cur_n-1) * 2) #p=0.15
    elif g_type == 'erdos_renyi_fixed':
        g = nx.gnm_random_graph(cur_n, edge * cur_n)
    elif g_type == 'powerlaw':
        g = nx.powerlaw_cluster_graph(n = cur_n, m = 4, p = 0.05)
    elif g_type == 'barabasi_albert':
        g = nx.barabasi_albert_graph(n = cur_n, m = edge)
    elif g_type == 'watts_strogatz':
        g = nx.watts_strogatz_graph(n = cur_n, k = cur_n // 10, p = 0.1)

    for edge in nx.edges(g):
        g[edge[0]][edge[1]]['weight'] = random.uniform(0,1)
    for node in g.nodes():
        g.nodes[node]['weight'] = random.uniform(0,1)

    return g


def getEdgeVar(m, v1, v2, vert):
    u1 = min(v1, v2)
    u2 = max(v1, v2)
    if not ((u1, u2) in vert):
        vert[(u1, u2)] = m.addVar(name='u%d_%d' %(u1, u2),
                                   vtype='B')

    return vert[(u1, u2)]


def getNodeVar(m, v, node):
    if not v in node:
        node[v] = m.addVar(name='v%d' %v,
                            vtype='B')

    return node[v]


def createOptVC(G):
    m = pyscipopt.Model()
    edgeVar = {}
    nodeVar = {}
    for j, (v1, v2) in enumerate(G.edges()):
        node1 = getNodeVar(m, v1, nodeVar)
        node2 = getNodeVar(m, v2, nodeVar)

        m.addCons((node1 + node2) >= 1)

    m.setObjective(quicksum(G.nodes[v]['weight'] * getNodeVar(m, v, nodeVar) for v in G.nodes()), sense = "minimize")
    return m

def generateInstance(max_n, min_n, 
                     g_type='erdos_renyi', edge=4, outPrefix=None, opt_problem = "MVC", id = 0, save_file = None):
    '''
    max_n, min_n: upper and lower bounds on the number of nodes in the graph
    edge: average edge degree per node
    g_type: type of random graph models: erdos_renyi, barabasi_albert
    id: index of the instance for naming purpose
    save_file: file name
    '''
    G = gen_graph(max_n, min_n, g_type, edge)
    
   
    P = createOptVC(G)


    if not (save_file is None):
        save_file = save_file % (id)
        P.writeProblem(save_file)
        
    
    return G, P



if __name__ == "__main__":
    path_MVC = "mvc_instance_%d.cip"
    rng = np.random.RandomState(0)
    
    SEED = 20240101
    random.seed(SEED)
    num_nodes = 2000
    G, P = generateInstance(num_nodes, num_nodes, g_type='barabasi_albert', edge=70, opt_problem = "MVC", id = 0, save_file = path_MVC)
        