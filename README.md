# RoCC Overlay for Coarse-Grained Reconfigurable Architectures (CGRAs)

This repository contains code for a RoCC (coprocessor for a Rocket Core) that can be added to the Chipyard repository as a hardware accelerator. This accelerator is designed to control a CGRA using custom instructions that control memory nodes for direct data access (dedicated DMA).

## Features

This project includes the following features:

- **RoCC for overlays**: The code generates a RoCC for overlays (CGRAs for FPGAs) with the desired number of input and output memory nodes. This allows for the creation of highly configurable CGRAs that can be used as hardware accelerators.

- **Custom instructions**: The RoCC uses custom instructions that enable control of the memory nodes for direct data access. This allows for efficient control between Rocket Core and the overlay.

- **Dedicated DMA**: The RoCC includes dedicated DMA nodes for efficient memory access. This enables high-speed data transfer between the CGRA and the main memory.

## Getting Started

To use this code, first ensure that you have the Chipyard 1.8.1 repository installed on your machine. Then, follow these steps:

1. Clone the repository to your local machine and add it as a submodule in the Chipyard repository (follow the steps on [Chipyard Doc](https://chipyard.readthedocs.io/en/1.8.1/Customization/Custom-Chisel.html).
2. Modify the parameters in the configuration file to define the desired number of input and output memory nodes.
3. Use the generated CGRA with the RoCC to accelerate your application.

## Contributing

If you would like to contribute to this project, please fork the repository and create a pull request with your changes. We welcome contributions that improve the functionality or usability of the code, or that provide additional features.

## License

This project is licensed under the GNU General Public License v3.0. Please see the [LICENSE](./LICENSE.md) file for more information.

## Contact

If you have any questions or concerns about this project, please contact the project owner at [mail](mailto:daniel.vazquez@upm.es). See the [AUTHORS](./AUTHORS.md) file for more information.
