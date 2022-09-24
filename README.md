# photometry_model_fitting
Photometry model fitting containing mouse model fit codes for Juan. All model fitting code is in the `model_fits.jl` file which contains code to fit the behavioural data to various Q learning variants, the habit model and the John Mikhael model. It computes parameters and log likelihoods for each model on the behavioural data.

It assumes the data is stored in a folder in the current directory called "Data_JC04" as in the saved folder on the intranet. The data is parsed and put into intermediate files that the model fits run off by the `data_parser.py` file. The data should be accessible on the internal intranet and Juan knows how/where it is stored.

I have also added pdfs of all the presentations I made to the group presenting the results as pdfs. I made them in beamer and so also have the overleaf repos but didn't think it would be that useful sharing them. If you want access to the repos directly, just ask me.
