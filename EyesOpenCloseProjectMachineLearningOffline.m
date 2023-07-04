% Script for identifying open and close eyes using Machine Learning algorithm approach from EEG data
% Prepared By:
% Rana Depto
% mail@ranadepto.com
% https://ranadepto.com

clc;        % Clear the Screen
clear;      % Clear the Workspace
close all;	% Close all Figures

% - Initial variables
fs = 256;
window_size = 5; % in seconds
addpath(genpath('data')) % adding data folder in the MATLAB path 
addpath(genpath('brainflow'))


%% 1: Signal Acquisition

% - Getting all CSV file names starting with "Eyes" and ending with ".csv" from the "data" folder.
files = dir('data/Eyes*.csv');

ch_o1 = [];
ch_o2 = [];
% - Reading all data
for i_file=1:length(files)
    file_name = files(i_file).name;
    try
        data = DataFilter.read_file(strcat('data/',file_name));
        % Reading first 50 seconds data from each dataset
        ch_o1 = [ch_o1 data(8, 1:12800)];
        ch_o2 = [ch_o2 data(9, 1:12800)];
    catch me
        disp(me)
    end
end

fprintf('\n --- Data Loaded ---\n');

%% 2: Signal Preprocessing
%     - Select Channels (O1 and O2)
%     - 5 Seconds Segment
%     - Data Labeling (0, 1)

% % - Select Channels (O1 and O2)
% ch_o1 = data(8, :);
% ch_o2 = data(9, :);

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

dataAll = [ch_o1_feature_alpha_power ch_o1_feature_beta_power];
labelAll = ch_o1_label;

% Cross varidation (train: 80%, test: 20%)
cv = cvpartition(size(dataAll,1),'HoldOut',0.2);
idx = cv.test;
% Separate to training and test data
dataTrainX = dataAll(~idx,:);
dataTestX  = dataAll(idx,:);
dataTrainY = labelAll(~idx,:);
dataTestY  = labelAll(idx,:);

% https://www.mathworks.com/discovery/machine-learning-models.html
modelLinR = fitlm(dataTrainX, dataTrainY); % Linear Regression
modelLogR = fitglm(dataTrainX, dataTrainY); % Logistic Regression	
modelSVM = fitcsvm(dataTrainX, dataTrainY); % Support Vector Machine (SVM)
modelSVMR = fitrsvm(dataTrainX, dataTrainY); % Support Vector Machine (SVM) Regression
modelKNN = fitcknn(dataTrainX, dataTrainY); % k Nearest Neighbor (kNN)	
modelEnsemble = fitcensemble(dataTrainX, dataTrainY); % Bagged and Boosted Decision Trees
modelNB = fitcnb(dataTrainX, dataTrainY); % Naive Bayes	


fprintf('\n --- Translation Algorithm ---\n');

%% 6: Analyzing Results

testSize=length(dataTestY);
prediction = zeros(testSize, 1);

for i=1:testSize
    prediction(i, 1)=predict(modelSVM, dataTestX(i,:) );   

    if prediction(i, 1)>=0.5
        prediction(i, 1)=1;
    else
        prediction(i, 1)=0;
    end
end

correctTrial = find(prediction-dataTestY==0);
successRate = length(correctTrial) / testSize;
fprintf('\nAccuracy %.2f%%\n', successRate*100);

