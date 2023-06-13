"""
test:
python corMIPGen.py --cor_file ~/Research/MIP_Instances/corGenerator/examples/cor-lat-2f+r-u-10-100-100-6174.cor --out_file ~/Research/MIP_Instances/corGenerator/examples/cor-lat-2f+r-u-10-100-100-6174.mps
"""

import os
import gurobipy as grb
import argparse
import networkx as nx
from IPython import embed

grb.setParam("LogFile","")
grb.setParam("LogToConsole",0)

parser = argparse.ArgumentParser()
parser.add_argument('--cor_file', required=True,
                    help=".cor file to use for MIP instance")
parser.add_argument('--budget_frac', required=True, type=float,
                    help="fraction of total cost allowed for budget")
parser.add_argument('--out_file', required=True,
                    help=".mps file to output to")


def parseCor(corlat_instance):
    """parses a corlat instance in .cor format into the networkx directed graph format

    Args:
        corlat_instance: file path of the corlat instance to parse

    Returns:
        a directed graph containing relevant information

    """
    assert os.path.exists(corlat_instance), "{} does not exist".format(corlat_instance)
    graph = nx.digraph.DiGraph()
    edges = []
    with open(corlat_instance, "r") as f:
        raw_data = list(map(lambda x:x.strip(), f.readlines()))

    for row in raw_data:
        row_type = row[0]
        if row_type == "p":
            # p n r
            #   n is the number of parcels, n is  an integer;
            #   r is the number of reserves, n is  an integer;
            num_parcels, num_reserves = map(int, row.split()[1:])
        elif row_type == "n":
            # n i b u c e i1 i2 ...  ie
            #   i is the id number of the node, i is an integer; 
            #   b whether the node is a reserve; b is 0 or 1; 
            #   u is the utility of the node; u is an integer; 
            #   c is the cost of the node; c is an integer; 
            #   e is the number of neighboring nodes; e is an integer; 
            #   ij is the id of neighbor node j (j=1,2, ... ,e)
            split_row = row.split()

            # get node features
            node_id, is_reserve, node_utility, node_cost, num_neighbors = map(int, split_row[1:6])

            # get neighbors
            neighbors = list(map(int, split_row[6:-1]))
            edges += [(node_id, neighbor_id) for neighbor_id in neighbors]
            edges += [(neighbor_id, node_id) for neighbor_id in neighbors]
            graph.add_node(node_id, is_reserve=is_reserve,
                node_utility=node_utility, node_cost=node_cost,
                num_neighbors=num_neighbors)

    graph.add_edges_from(edges)
    return graph



def generateMIPInstance(graph_data, budget=None, budget_frac=None):
    """creates a gurobi MIP instance from a corlat file

    Args:
        corlat_instance: file path of the corlat instance to parse

    Returns:
        a directed graph containing relevant information

    """
    assert budget is not None or budget_frac is not None, "one of {budget | budget_frac} must be passed"
    if budget is None:
        total_cost = sum([node_data["node_cost"] for _,node_data  in graph_data.nodes.items()])
        budget = budget_frac*total_cost
    n = len(graph_data.nodes)

    terminal_nodes = list(filter(lambda x:graph_data.nodes[x]["is_reserve"], graph_data.nodes))
    r = terminal_nodes[0]

    # create gurobi instance
    model = grb.Model()

    model.setAttr("modelSense", grb.GRB.MINIMIZE)
    # (4)
    node_vars = {node_id: model.addVar(obj=-node_data["node_utility"], 
                                        vtype=grb.GRB.BINARY,
                                        name="purchase_%d"%node_id)
        for node_id, node_data in graph_data.nodes.items()}

    # (9)
    flow_vars = {edge: model.addVar(vtype=grb.GRB.CONTINUOUS, lb=0, name="flow_"+str(edge).replace(" ",""))
        for edge in graph_data.edges}

    source_var = model.addVar(vtype=grb.GRB.CONTINUOUS, lb=0, name="x_0")
    source_flow_var = model.addVar(vtype=grb.GRB.CONTINUOUS, lb=0, name="y_0t")

    model.update()

    # (2)
    total_cost = grb.quicksum([graph_data.nodes[node]["node_cost"]*node_vars[node] for node in graph_data.nodes])
    model.addConstr(total_cost <= budget)

    # (3)
    for t in terminal_nodes:
        model.addConstr(node_vars[t] == 1)

    # (5)
    model.addConstr(source_var+source_flow_var == n)

    # (6)
    for edge in graph_data.edges:
        i,j = edge
        model.addConstr(flow_vars[(i,j)] <= n*node_vars[j])

    # (7)
    incoming_flow = {}
    outgoing_flow = {}
    for j in graph_data.nodes:
        incoming_flow[j] = grb.quicksum([flow_vars[edge] for edge in graph_data.edges if edge[1] == j])
        if j == r:
            incoming_flow[j] += source_flow_var
        outgoing_flow[j] = grb.quicksum([flow_vars[edge] for edge in graph_data.edges if edge[0] == j])
        model.addConstr(incoming_flow[j] == node_vars[j] + outgoing_flow[j])

    # (8)
    num_nodes_selected = grb.quicksum([node_vars[node] for node in graph_data.nodes])
    model.addConstr(num_nodes_selected == source_flow_var)

    model.update()
    return model

if __name__ == '__main__':
    args = parser.parse_args()

    # parse corlat instance
    graph_data = parseCor(args.cor_file)
    
    # create MIP instance from corlat data and budget fraction
    model = generateMIPInstance(graph_data, budget_frac=args.budget_frac)
    model.write(args.out_file)



