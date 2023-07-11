% Script for extracting 5-bands from EEG data
% Prepared By:
% Rana Depto
% mail@ranadepto.com
% https://ranadepto.com

clc;        % Clear the Screen
clear;      % Clear the Workspace
close all;	% Close all Figures

% - Initial variables
file_name = 'EyesSubject1Session1.csv';
fs = 256;
addpath(genpath('data')) % adding data folder in the MATLAB path
addpath(genpath('brainflow'))

selected_channel = 8; % Change accordingly
selected_second = 9; % Change accordingly. This is going to define which second's data we are going to select to plot.

selected_channel = selected_channel + 1;
starts = ((selected_second-1) * fs) + 1;
ends = selected_second * fs;

% - Importing data
data = importdata(file_name);
% data = DataFilter.read_file(strcat('data/',file_name)); % Using BrainFlow API
% temp_raw = data.data(starts:ends, channel)';
temp_raw = data(starts:ends, selected_channel)';
temp = temp_raw;

% % - 49-52Hz Band-stop Filter
% start_freq_bs = 49.0;
% stop_freq_bs = 52.0;
% filter_order_bs = 3;
% temp = DataFilter.perform_bandstop(temp, fs, start_freq_bs, stop_freq_bs, filter_order_bs, int32(FilterTypes.BUTTERWORTH), 0.0);

% - Delta Band
start_freq_bp = 0.5;
stop_freq_bp = 4.0;
filter_order_bp = 3;
delta = DataFilter.perform_bandpass(temp, fs, start_freq_bp, stop_freq_bp, filter_order_bp, int32(FilterTypes.BUTTERWORTH), 0.0);

% - Theta Band
start_freq_bp = 4.0;
stop_freq_bp = 8.0;
filter_order_bp = 3;
theta = DataFilter.perform_bandpass(temp, fs, start_freq_bp, stop_freq_bp, filter_order_bp, int32(FilterTypes.BUTTERWORTH), 0.0);

% - Alpha Band
start_freq_bp = 8.0;
stop_freq_bp = 13.0;
filter_order_bp = 3;
alpha = DataFilter.perform_bandpass(temp, fs, start_freq_bp, stop_freq_bp, filter_order_bp, int32(FilterTypes.BUTTERWORTH), 0.0);

% - Beta Band
start_freq_bp = 13.0;
stop_freq_bp = 30.0;
filter_order_bp = 3;
beta = DataFilter.perform_bandpass(temp, fs, start_freq_bp, stop_freq_bp, filter_order_bp, int32(FilterTypes.BUTTERWORTH), 0.0);

% - Gamma Band
start_freq_bp = 30.0;
stop_freq_bp = 100.0;
filter_order_bp = 3;
gamma = DataFilter.perform_bandpass(temp, fs, start_freq_bp, stop_freq_bp, filter_order_bp, int32(FilterTypes.BUTTERWORTH), 0.0);



% - Plotting 5 Bands
figure

subplot(6,1,1)
plot(1/fs : 1/fs : length(temp)/fs, temp_raw);
title('Raw Signal');

subplot(6,1,2)
plot(1/fs : 1/fs : length(delta)/fs, delta);
title('Delta (0.5-4Hz)');

subplot(6,1,3)
plot(1/fs : 1/fs : length(theta)/fs, theta);
title('Theta (4-8Hz)');

subplot(6,1,4)
plot(1/fs : 1/fs : length(alpha)/fs, alpha);
title('Alpha (8-13Hz)');

subplot(6,1,5)
plot(1/fs : 1/fs : length(beta)/fs, beta);
title('Beta (13-30Hz)');

subplot(6,1,6)
plot(1/fs : 1/fs : length(gamma)/fs, gamma);
title('Gamma (30-100Hz)');



