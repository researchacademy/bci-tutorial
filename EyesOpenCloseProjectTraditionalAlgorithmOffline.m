% Script for identifying open and close eyes using traditional algorithm approach from EEG data
% Prepared By:
% Rana Depto
% mail@ranadepto.com
% https://ranadepto.com

clc;        % Clear the Screen
clear;      % Clear the Workspace
close all;	% Close all Figures

% - Initial variables
file_name = 'EyesSubject1Session2.csv';
fs = 256;
window_size = 5; % in seconds
addpath(genpath('data')) % adding data folder in the MATLAB path 
addpath(genpath('brainflow'))

%% 1: Signal Acquisition
% -- This is an offline analysis. So, we are going to load data only.

% - Importing data
% data = importdata(file_name); 
data = DataFilter.read_file(strcat('data/',file_name)); % Using BrainFlow API

fprintf('\n --- Data Loaded ---\n');

%% 2: Signal Preprocessing
%     - Select Channels (O1 and O2)
%     - 5 Seconds Segment
%     - Data Labeling (0, 1)

% - Select Channels (O1 and O2)
ch_o1 = data(8, :);
ch_o2 = data(9, :);

% - 5 Seconds Segment
segment_data_size = fs*window_size;
total_trial = floor(length(ch_o1)/segment_data_size);
ch_o1_segmented = reshape(ch_o1(1:segment_data_size*total_trial), segment_data_size, [])';
ch_o2_segmented = reshape(ch_o2(1:segment_data_size*total_trial), segment_data_size, [])';

% - Data Labeling (0, 1)
ch_o1_label = nan(floor(length(ch_o1)/segment_data_size), 1);
ch_o2_label = nan(floor(length(ch_o2)/segment_data_size), 1);
for i=1:total_trial
    ch_o1_label(i,1) = (mod(i,2) == 1);
    ch_o2_label(i,1) = (mod(i,2) == 1);
end

fprintf('\n --- Signal Preprocessed ---\n');

%% 3: Signal Denoising
%     - 1-40Hz Band-pass Filter
%     - 49-52Hz Notch Filter
%     ~ Remove 1st and 5th second data from each segment for EOG (eye movement for opening/closing)

% - 1-40Hz Band-pass Filter
lowerRange_bp = 1.0;
upperRange_bp = 40.0;
center_freq_bp = (upperRange_bp + lowerRange_bp) / 2.0;
band_width_bp = upperRange_bp - lowerRange_bp;
filter_order_bp = 3;
ch_o1_denoised = nan(total_trial, segment_data_size);
ch_o2_denoised = nan(total_trial, segment_data_size);
for i=1:total_trial
    ch_o1_denoised(i,:) = DataFilter.perform_bandpass(ch_o1_segmented(i,:), fs, center_freq_bp, band_width_bp, filter_order_bp, int32(FilterTypes.BUTTERWORTH), 0.0);
    ch_o2_denoised(i,:) = DataFilter.perform_bandpass(ch_o2_segmented(i,:), fs, center_freq_bp, band_width_bp, filter_order_bp, int32(FilterTypes.BUTTERWORTH), 0.0);
end

% - 49-52Hz Band-stop Filter
lowerRange_bs = 49.0;
upperRange_bs = 52.0;
filter_order_bs = 3;
center_freq_bs = (upperRange_bs + lowerRange_bs) / 2.0;
band_width_bs = upperRange_bs - lowerRange_bs;
for i=1:total_trial
    ch_o1_denoised(i,:) = DataFilter.perform_bandstop(ch_o1_denoised(i,:), fs, center_freq_bs, band_width_bs, filter_order_bs, int32(FilterTypes.BUTTERWORTH), 0.0);
    ch_o2_denoised(i,:) = DataFilter.perform_bandstop(ch_o2_denoised(i,:), fs, center_freq_bs, band_width_bs, filter_order_bs, int32(FilterTypes.BUTTERWORTH), 0.0);
end

% ~ Remove 1st and 5th second data from each segment for EOG (eye movement for opening/closing)
% TODO for your practice
% Hint: out of 1:1280 data points of each segment, take 257:1024

fprintf('\n --- Signal Denoised ---\n');

%% 4: Feature Extraction
%     - α (Alpha) Power
%     - β (Beta) Power 

ch_o1_feature_alpha_power = nan(total_trial, 1);
ch_o1_feature_beta_power = nan(total_trial, 1);
ch_o2_feature_alpha_power = nan(total_trial, 1);
ch_o2_feature_beta_power = nan(total_trial, 1);
nfft = DataFilter.get_nearest_power_of_two(fs);

for i=1:total_trial
    original_data = ch_o1_denoised(i,:);
    detrended = DataFilter.detrend(original_data, int32(DetrendOperations.LINEAR));
    [ampls, freqs] = DataFilter.get_psd_welch(detrended, nfft, nfft / 2, fs, int32(WindowFunctions.HANNING));
    ch_o1_feature_alpha_power(i) = DataFilter.get_band_power(ampls, freqs, 8.0, 13.0);
    ch_o1_feature_beta_power(i) = DataFilter.get_band_power(ampls, freqs, 14.0, 30.0);

    original_data = ch_o2_denoised(i,:);
    detrended = DataFilter.detrend(original_data, int32(DetrendOperations.LINEAR));
    [ampls, freqs] = DataFilter.get_psd_welch(detrended, nfft, nfft / 2, fs, int32(WindowFunctions.HANNING));
    ch_o2_feature_alpha_power(i) = DataFilter.get_band_power(ampls, freqs, 8.0, 13.0);
    ch_o2_feature_beta_power(i) = DataFilter.get_band_power(ampls, freqs, 14.0, 30.0);
end

fprintf('\n --- Features Extracted ---\n');

%% 5: Translation Algorithm

% - Algorithm 1: Alpha Power > Beta Power = Close
% If beta power is higher than alpha power, it will return 1. In our label, 1 means eyes open and 0 means eyes closed.
ch_o1_label_predicted = ch_o1_feature_alpha_power < ch_o1_feature_beta_power;
ch_o2_label_predicted = ch_o2_feature_alpha_power < ch_o2_feature_beta_power;

% Accuracy on channel O1
ch_o1_correctTrial = find(ch_o1_label_predicted - ch_o1_label == 0);
ch_o1_successRate = length(ch_o1_correctTrial) / total_trial;
fprintf('\nAccuracy Algorithm 1 O1 = %f', ch_o1_successRate);
% Accuracy on channel O2
ch_o2_correctTrial = find(ch_o2_label_predicted - ch_o2_label == 0);
ch_o2_successRate = length(ch_o2_correctTrial) / total_trial;
fprintf('\nAccuracy Algorithm 1 O2 = %f\n', ch_o2_successRate);



% - Algorithm 2: alpha_power(i) >= mean(alpha_power) && beta_power(i) <= mean(beta_power) = Close Eyes
ch_o1_label_predicted2 = nan(total_trial, 1);
ch_o2_label_predicted2 = nan(total_trial, 1);
for i=1:total_trial
    if ch_o1_feature_alpha_power(i) >= mean(ch_o1_feature_alpha_power) && ch_o1_feature_beta_power(i) <= mean(ch_o1_feature_beta_power)
        ch_o1_label_predicted2(i) = 0;
    else
        ch_o1_label_predicted2(i) = 1;
    end
    
    if ch_o2_feature_alpha_power(i) >= mean(ch_o2_feature_alpha_power) && ch_o2_feature_beta_power(i) <= mean(ch_o2_feature_beta_power)
        ch_o2_label_predicted2(i) = 0;
    else
        ch_o2_label_predicted2(i) = 1;
    end
end



% Accuracy on channel O1
ch_o1_correctTrial2 = find(ch_o1_label_predicted2 - ch_o1_label == 0);
ch_o1_successRate2 = length(ch_o1_correctTrial2) / total_trial;
fprintf('\nAccuracy Algorithm 2 O1 = %f', ch_o1_successRate2);
% Accuracy on channel O2
ch_o2_correctTrial2 = find(ch_o2_label_predicted2 - ch_o2_label == 0);
ch_o2_successRate2 = length(ch_o2_correctTrial2) / total_trial;
fprintf('\nAccuracy Algorithm 2 O2 = %f\n', ch_o2_successRate2);



% - Algorithm 3: alpha_power(i) >= open_eyes_alpha_power_avarage && beta_power(i) <= open_eyes_beta_power_avarage = Close Eyes
% Channel O1 Alpha Power Average (Open & Close Individually)
ch_o1_open_eyes_alpha_power_avarage = sum(ch_o1_feature_alpha_power(1:2:end)) / (total_trial/2);
ch_o1_close_eyes_alpha_power_avarage = sum(ch_o1_feature_alpha_power(2:2:end)) / (total_trial/2);
% Channel O1 Beta Power Average (Open & Close Individually)
ch_o1_open_eyes_beta_power_avarage = sum(ch_o1_feature_beta_power(1:2:end)) / (total_trial/2);
ch_o1_close_eyes_beta_power_avarage = sum(ch_o1_feature_beta_power(2:2:end)) / (total_trial/2);

% Channel O2 Alpha Power Average (Open & Close Individually)
ch_o2_open_eyes_alpha_power_avarage = sum(ch_o2_feature_alpha_power(1:2:end)) / (total_trial/2);
ch_o2_close_eyes_alpha_power_avarage = sum(ch_o2_feature_alpha_power(2:2:end)) / (total_trial/2);
% Channel O2 Beta Power Average (Open & Close Individually)
ch_o2_open_eyes_beta_power_avarage = sum(ch_o2_feature_beta_power(1:2:end)) / (total_trial/2);
ch_o2_close_eyes_beta_power_avarage = sum(ch_o2_feature_beta_power(2:2:end)) / (total_trial/2);

ch_o1_label_predicted3 = nan(total_trial, 1);
ch_o2_label_predicted3 = nan(total_trial, 1);
for i=1:total_trial
    if ch_o1_feature_alpha_power(i) >= ch_o1_open_eyes_alpha_power_avarage && ch_o1_feature_beta_power(i) <= ch_o1_open_eyes_beta_power_avarage
        ch_o1_label_predicted3(i) = 0;
    else
        ch_o1_label_predicted3(i) = 1;
    end
    
    if ch_o2_feature_alpha_power(i) >= ch_o2_open_eyes_alpha_power_avarage && ch_o2_feature_beta_power(i) <= ch_o2_open_eyes_beta_power_avarage
        ch_o2_label_predicted3(i) = 0;
    else
        ch_o2_label_predicted3(i) = 1;
    end
end
        
% Accuracy on channel O1
ch_o1_correctTrial3 = find(ch_o1_label_predicted3 - ch_o1_label == 0);
ch_o1_successRate3 = length(ch_o1_correctTrial3) / total_trial;
fprintf('\nAccuracy Algorithm 3 O1 = %f', ch_o1_successRate3);
% Accuracy on channel O2
ch_o2_correctTrial3 = find(ch_o2_label_predicted3 - ch_o2_label == 0);
ch_o2_successRate3 = length(ch_o2_correctTrial3) / total_trial;
fprintf('\nAccuracy Algorithm 3 O2 = %f\n\n', ch_o2_successRate3);


fprintf('\n --- Translation Algorithm ---\n');


