from pathlib import Path

import fire
import numpy as np
import networkx as nx

import gisp


def read_dimacs(dimacs_file):
    with open(dimacs_file, "r") as f:
        data = f.readlines()
    edges = []
    for row in data:
        if row.startswith("e"):
            i, j = row.split()[1:]
            edges.append((int(i), int(j)))
    return nx.Graph(edges)


def main(seed=1, num_instances_per_graph=20, alpha=0.75, node_weight=100, edge_cost=1, dimacs_graph_dir="./DIMACS_1993", mip_dir="./GISP_DIMACS", mip_extension="mps"):
    """
    Generates a distribution of generalized independent set instances based on graphs from the DIMACS 1993 challenge.
    Saves the instances to a directory structure like:
    GISP_DIMACS (mip_dir)
    ├── train
    │   ├── C125.9_mip_00.mps (mip_extension)
    │   ├── ...
    ├── test
    The distributions are supposed to mimic those from Khalil et al 2017 (https://ekhalil.com/files/papers/KhaDilNemetal17.pdf).
    """
    rng = np.random.RandomState(seed)
    partiton_seed = rng.randint(2**31)
    dimacs_graph_path = Path(dimacs_graph_dir)
    mip_path = Path(mip_dir)
    for graph_file in dimacs_graph_path.rglob("*.clq"):
        graph = read_dimacs(graph_file)
        graph_instance_output_dir = mip_path / \
            graph_file.relative_to(dimacs_graph_path).parent
        graph_name = graph_file.stem
        for instance_num in range(num_instances_per_graph):
            E1, E2 = gisp.partition_edges(graph.edges, alpha, partiton_seed)
            problem = gisp.generate_MIP(
                graph.nodes, E1, E2, node_weight, edge_cost)
            output_filename = graph_instance_output_dir / \
                f"{graph_name}_mip_{instance_num}.{mip_extension}"
            output_filename.parent.mkdir(parents=True, exist_ok=True)
            problem.writeMPS(output_filename)


if __name__ == "__main__":
    fire.Fire(main)
