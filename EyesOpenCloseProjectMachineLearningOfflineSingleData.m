% Script for identifying open and close eyes using Machine Learning algorithms approach from a single EEG data
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
start_freq_bp = 1.0;
stop_freq_bp = 40.0;
filter_order_bp = 3;
ch_o1_denoised = nan(total_trial, segment_data_size);
ch_o2_denoised = nan(total_trial, segment_data_size);
for i=1:total_trial
    ch_o1_denoised(i,:) = DataFilter.perform_bandpass(ch_o1_segmented(i,:), fs, start_freq_bp, stop_freq_bp, filter_order_bp, int32(FilterTypes.BUTTERWORTH), 0.0);
    ch_o2_denoised(i,:) = DataFilter.perform_bandpass(ch_o2_segmented(i,:), fs, start_freq_bp, stop_freq_bp, filter_order_bp, int32(FilterTypes.BUTTERWORTH), 0.0);
end

% - 49-52Hz Band-stop Filter
start_freq_bs = 49.0;
stop_freq_bs = 52.0;
filter_order_bs = 3;
for i=1:total_trial
    ch_o1_denoised(i,:) = DataFilter.perform_bandstop(ch_o1_denoised(i,:), fs, start_freq_bs, stop_freq_bs, filter_order_bs, int32(FilterTypes.BUTTERWORTH), 0.0);
    ch_o2_denoised(i,:) = DataFilter.perform_bandstop(ch_o2_denoised(i,:), fs, start_freq_bs, stop_freq_bs, filter_order_bs, int32(FilterTypes.BUTTERWORTH), 0.0);
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
    [ampls, freqs] = DataFilter.get_psd_welch(detrended, nfft, nfft / 2, fs, int32(WindowOperations.HANNING));
    ch_o1_feature_alpha_power(i) = DataFilter.get_band_power(ampls, freqs, 8.0, 13.0);
    ch_o1_feature_beta_power(i) = DataFilter.get_band_power(ampls, freqs, 14.0, 30.0);

    original_data = ch_o2_denoised(i,:);
    detrended = DataFilter.detrend(original_data, int32(DetrendOperations.LINEAR));
    [ampls, freqs] = DataFilter.get_psd_welch(detrended, nfft, nfft / 2, fs, int32(WindowOperations.HANNING));
    ch_o2_feature_alpha_power(i) = DataFilter.get_band_power(ampls, freqs, 8.0, 13.0);
    ch_o2_feature_beta_power(i) = DataFilter.get_band_power(ampls, freqs, 14.0, 30.0);
end

fprintf('\n --- Features Extracted ---\n');

%% 5: Translation Algorithm

trainX = [ch_o1_feature_alpha_power ch_o1_feature_beta_power];
trainY = ch_o1_label;

% https://www.mathworks.com/discovery/machine-learning-models.html
modelSVM = fitcsvm(trainX, trainY); % Support Vector Machine (SVM)
modelSVMR = fitrsvm(trainX, trainY); % Support Vector Machine (SVM) Regression
modelLinR = fitlm(trainX, trainY); % Linear Regression
modelLogR = fitglm(trainX, trainY); % Logistic Regression
modelKNN = fitcknn(trainX, trainY); % k Nearest Neighbor (kNN)	
modelEnsemble = fitcensemble(trainX, trainY); % Bagged and Boosted Decision Trees
modelNB = fitcnb(trainX, trainY); % Naive Bayes	


test_result=predict(modelSVM, [ch_o2_feature_alpha_power(1) ch_o2_feature_beta_power(1)]);   
fprintf('\nChannel O2 First Data > Prediction: %d | Actual: %d\n', test_result, ch_o1_label(1));
test_result=predict(modelSVM, [ch_o2_feature_alpha_power(2) ch_o2_feature_beta_power(2)]);   
fprintf('Channel O2 Second Data > Prediction: %d | Actual: %d\n', test_result, ch_o1_label(2));


fprintf('\n --- Translation Algorithm ---\n');

%% 6: Analyzing Results

testSize=length(ch_o2_feature_alpha_power);
prediction = zeros(testSize, 1);

for i=1:testSize
    prediction(i, 1)=predict(modelSVM, [ch_o2_feature_alpha_power(i) ch_o2_feature_beta_power(i)]);   

    if prediction(i, 1)>=0.5
        prediction(i, 1)=1;
    else
        prediction(i, 1)=0;
    end
end

correctTrial = find(prediction-ch_o1_label==0);
successRate = length(correctTrial) / testSize;
fprintf('\nAccuracy %.2f%%\n', successRate*100);


