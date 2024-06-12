# Generalized Independent Set Problem
Generator code for GISP instances

generate a single instance using:
```bash
python gisp.py --filename=mip_instance.mps --nodes=75 --edge_prob=0.5 --edge_cost=1 --node_weight=100 --alpha=0.75 --seed=1
```

Vary the seed to get different instances

## Citations
Original formulation
```
@article{hochbaum1997forest,
  title={Forest harvesting and minimum cuts: a new approach to handling spatial constraints},
  author={Hochbaum, Dorit S and Pathria, Anu},
  journal={Forest Science},
  volume={43},
  number={4},
  pages={544--554},
  year={1997},
  publisher={Oxford University Press}
}
```

Generator and problem distribution
```
@inproceedings{ferber2022learning,
  title={Learning pseudo-backdoors for mixed integer programs},
  author={Ferber, Aaron and Song, Jialin and Dilkina, Bistra and Yue, Yisong},
  booktitle={International Conference on Integration of Constraint Programming, Artificial Intelligence, and Operations Research},
  pages={91--102},
  year={2022},
  organization={Springer}
}
```
