GLOceanKit
===========
GLOceanKit is a collection of models and analysis tools for physical oceanography.

The code is in written in two different languages: Matlab and Objective-C, but not all models or analysis tools are available in both languages.

[Matlab](Matlab/)
-------
The Matlab directory contains the following subdirectories of models and tools,
- [Diffusivity](Matlab/Diffusivity) A collection of analysis tools for computing relative diffusivity from particles.
- [InternalModes](Matlab/InternalModes) Tools solving the vertical mode eigenvalue problem with very high accuracy.
- [InternalWaveModel](Matlab/InternalWaveModel) A linear internal wave model.
- [InternalWaveSpectrum](Matlab/InternalWaveSpectrum) Tools for computing the Garrett-Munk spectrum and its approximations.
- [OceanBoundaryLayer](Matlab/OceanBoundaryLayer) A few simple ocean boundary layer models taken from Elipot and Gille (2009).
- [Quasigeostrophy](Matlab/Quasigeostrophy) Tools for analyzing the output of the Quasigeostrophic model.

[Objective-C](GLOceanKit/)
-------
Contains internal modes routines, internal wave model, and a QG model.