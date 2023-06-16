from pathlib import Path

import fire
import numpy as np
import networkx as nx

import gisp


def generate(setting_name="easy", num_instances_per_set=100, seed=1, nodes=150, edge_prob=0.3, edge_cost=1, node_weight=100, alpha=0.25, mip_extension="mps"):
    """
    Generate a distribution of generalized independent set instances.
    Saves the instances to a directory structure like:
    GISP_GNP
    ├── easy (setting_name)
    │   ├── train
    │   │   ├── gisp_erdos_renyi_00.mps (mip_extension)
    │   │   ├── ...
    │   ├── val
    │   ├── test

    Parameters
    ----------
    setting_name : str, optional
        Name of the setting to generate instances for. Default is "easy".
    num_instances_per_set : int, optional
        Number of instances to generate per set. Default is 100.
    seed : int, optional
        Random seed. Default is 1.
    nodes : int, optional
        Number of nodes in the graph. Default is 150.
    edge_prob : float, optional
        Probability of an edge existing between two nodes. Default is 0.3.
    edge_cost : int, optional
        Cost of an edge. Default is 1.
    node_weight : int, optional
        Weight of a node. Default is 100.
    alpha : float, optional
        Fraction of removable edges. Default is 0.25.
    mip_extension : str, optional
        Extension of the MIP file. Default is "mps".
    """
    output_path = Path("GISP_GNP") / setting_name
    rng = np.random.RandomState(seed)
    for group in ["train", "val", "test"]:
        group_path = output_path / group
        group_path.mkdir(parents=True, exist_ok=True)
        for i in range(num_instances_per_set):
            graph_seed = rng.randint(2**31)
            # generate graph (or collect from dimacs)
            graph = nx.erdos_renyi_graph(nodes, edge_prob, seed=graph_seed)

            # generate mip
            partiton_seed = rng.randint(2**31)
            E1, E2 = gisp.partition_edges(graph.edges, alpha, partiton_seed)
            problem = gisp.generate_MIP(
                graph.nodes, E1, E2, node_weight, edge_cost)
            output_file = group_path / \
                f"gisp_erdos_renyi_{i:02d}.{mip_extension}"
            problem.writeMPS(output_file)


if __name__ == "__main__":
    """
    easy instances are with default settings
    python generate_erdos_renyi.py
    harder instances can be generated with
    python generate_erdos_renyi.py --setting_name="hard" --nodes=175
    """
    fire.Fire(generate)
