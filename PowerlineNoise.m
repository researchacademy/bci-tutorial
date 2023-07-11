% Script for finding, visualizing and denoising powerline noise
% Prepared By:
% Rana Depto
% mail@ranadepto.com
% https://ranadepto.com

clc;        % Clear the Screen
clear;      % Clear the Workspace
close all;	% Close all Figures

% - Initial variables
% file_name = 'Test.csv';
file_name = 'EyesSubject1Session1.csv';
fs = 256;
addpath(genpath('data')) % adding data folder in the MATLAB path
addpath(genpath('brainflow'))

selected_channel = 7; % Change accordingly
selected_channel = selected_channel + 1;

% - Importing data
data = importdata(file_name);
original_data = data(1:end, selected_channel)';

% - Get Power Spectral Density (PSD) using Welch method
nfft = DataFilter.get_nearest_power_of_two(fs);
detrended = DataFilter.detrend(original_data, int32(DetrendOperations.LINEAR));
[ampls_original, freqs_original] = DataFilter.get_psd_welch(detrended, nfft, nfft / 2, fs, int32(WindowOperations.HANNING));

figure
plot(freqs_original, ampls_original);
title('Frequency Domain with the Powerline Noise');


% - 49-54Hz Band-stop Filter
start_freq_bs = 49.0;
stop_freq_bs = 52.0;
filter_order_bs = 3;
denoised_data = DataFilter.perform_bandstop(original_data, fs, start_freq_bs, stop_freq_bs, filter_order_bs, int32(FilterTypes.BUTTERWORTH), 0.0);

detrended = DataFilter.detrend(denoised_data, int32(DetrendOperations.LINEAR));
[ampls_denoised, freqs_denoised] = DataFilter.get_psd_welch(detrended, nfft, nfft / 2, fs, int32(WindowOperations.HANNING));

figure
plot(freqs_denoised, ampls_denoised);
title('Frequency Domain after Denoising the Powerline Noise');

