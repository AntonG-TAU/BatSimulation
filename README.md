# Bats Swarm Simulation
Omer Keinan, Anton Gurevich

Implementation of the swarming model “No-regret Exploration in Goal-Oriented Reinforcement Learning”, Tarbouriech et al., 2019. on bats Matlab simulation

Any modification made in the code are commented with  `omer&anton` making it easier to find what changes we've made in the original code.

`/videos` - Videos of the experiments are 

Install the experiment environments by running the following:

```
cd fozen_lake_env
pip install -e .
cd ..
cd maze_env
pip install -e .
```

To run the experiment, just open `algorithms/uc_ssp/uc_ssp.py` and modify the parameters according to the comments at the bottom.
