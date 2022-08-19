SNE, the sparse neural engine, is a fully digital spiking neural network accelerator that can handle sparse convolutions efficiently. This repository contains the RTL description of the accelerator, as well as a basic test to simulate the accelerator standalone.

## structure

The SNE repository is structured as follows:

- `rtl` contains the RTL code and Verilog testbench for CUTIE
- `sim` contains the files required to start the simulation
- `vsne_conv` contains a high level python model of the SNE accelerator
- `utils` contains several simulation utility script

### Dependencies

This repo uses Bender (https://github.com/pulp-platform/bender) to manage its dependencies and generate compilation scripts.
For this reason, the build process of this project will download a current version of the Bender binary.

to fetch all the needed dependencies, execute:

`make checkout`

### Simulating the SNE platform

To build the RTL platform, execute the following command. 

`source config.sh`

And then run:

`make build opt`

This will generate the required scripts and build the RTL. Then, to run a basic convolutional regression test, run:

`make -C sim all`

Currently, Modelsim is the only supported simulation platform.

## License

SNE is released under permissive open source licenses. SNE's source code is released under the Solderpad v0.51 (`SHL-0.51`) license see [`LICENSE`](LICENSE). The code in `vsne_conv` is released under the Apache License 2.0 (`Apache-2.0`) see [`vsne_conv/LICENSE`](vsne_conv/LICENSE).

## Publication

If you find SNE useful in your research, you can cite us:

```
@INPROCEEDINGS{9774552,
  author={Di Mauro, Alfio and Prasad, Arpan Suravi and Huang, Zhikai and Spallanzani, Matteo and Conti, Francesco and Benini, Luca},
  booktitle={2022 Design, Automation & Test in Europe Conference & Exhibition (DATE)}, 
  title={SNE: an Energy-Proportional Digital Accelerator for Sparse Event-Based Convolutions}, 
  year={2022},
  volume={},
  number={},
  pages={825-830},
  doi={10.23919/DATE54114.2022.9774552}}
```


