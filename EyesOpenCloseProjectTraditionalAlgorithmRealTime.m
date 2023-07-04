% Script for identifying open and close eyes using traditional algorithm approach from EEG data
% Prepared By:
% Rana Depto
% mail@ranadepto.com
% https://ranadepto.com

clc;        % Clear the Screen
clear;      % Clear the Workspace
close all;	% Close all Figures

openBCI_serial_port = '/dev/cu.usbserial-DM01N5OD'; % Change it accordingly
file_name = 'data/EyesRealTimeSubject1Session1.csv';
fs = 256;
data_save = [];
window_size = 5; % in seconds
total_trial = 12;

addpath(genpath('data'))
addpath(genpath('brainflow'))
BoardShim.set_log_file('brainflow.log');
BoardShim.enable_dev_board_logger();
params = BrainFlowInputParams();
params.serial_port = openBCI_serial_port;
board_shim = BoardShim(-1, params); % BoardIds.SYNTHETIC_BOARD (-1)  |  BoardIds.CYTON_BOARD (0)

% Band-pass filter variables
lowerRange_bp = 1.0;
upperRange_bp = 40.0;
center_freq_bp = (upperRange_bp + lowerRange_bp) / 2.0;
band_width_bp = upperRange_bp - lowerRange_bp;
filter_order_bp = 3;
% Band-stop filter variables
lowerRange_bs = 49.0;
upperRange_bs = 52.0;
filter_order_bs = 3;
center_freq_bs = (upperRange_bs + lowerRange_bs) / 2.0;
band_width_bs = upperRange_bs - lowerRange_bs;

nfft = DataFilter.get_nearest_power_of_two(fs);

%% Real-time

try
    board_shim.prepare_session();
    board_shim.start_stream(450000, '');

    for i_segment = 1:total_trial
        sound(sin(0:300)); % play beep sound for 300ms at the beginning of each 5 seconds window
        pause(window_size);
        disp(strcat('Elapsed: ', num2str(i_segment*window_size), ' Seconds'));

        % 1: Signal Acquisition
        data = board_shim.get_board_data(board_shim.get_board_data_count());
        data_save = [data_save data];

        % 2: Signal Preprocessing
        % - Select Channels (O1 and O2)
        ch_o1 = data(8, :);
        ch_o2 = data(9, :);

        % 3: Signal Denoising
        % - 1-40Hz Band-pass Filter
        ch_o1_denoised = DataFilter.perform_bandpass(ch_o1, fs, center_freq_bp, band_width_bp, filter_order_bp, int32(FilterTypes.BUTTERWORTH), 0.0);
        ch_o2_denoised = DataFilter.perform_bandpass(ch_o2, fs, center_freq_bp, band_width_bp, filter_order_bp, int32(FilterTypes.BUTTERWORTH), 0.0);
        % - 49-52Hz Band-stop Filter
        ch_o1_denoised = DataFilter.perform_bandstop(ch_o1_denoised, fs, center_freq_bs, band_width_bs, filter_order_bs, int32(FilterTypes.BUTTERWORTH), 0.0);
        ch_o2_denoised = DataFilter.perform_bandstop(ch_o2_denoised, fs, center_freq_bs, band_width_bs, filter_order_bs, int32(FilterTypes.BUTTERWORTH), 0.0);
        % ~ Remove 1st and 5th second data from each segment for EOG (eye movement for opening/closing)
        % TODO for your practice
        % Hint: out of 1:segment_data_size data points of each segment, take fs+1:segment_data_size-fs

        % 4: Feature Extraction
        % - α (Alpha) Power and β (Beta) Power for O1
        original_data = ch_o1_denoised;
        detrended = DataFilter.detrend(original_data, int32(DetrendOperations.LINEAR));
        [ampls, freqs] = DataFilter.get_psd_welch(detrended, nfft, nfft / 2, fs, int32(WindowFunctions.HANNING));
        ch_o1_feature_alpha_power = DataFilter.get_band_power(ampls, freqs, 8.0, 13.0);
        ch_o1_feature_beta_power = DataFilter.get_band_power(ampls, freqs, 14.0, 30.0);
        % - α (Alpha) Power and β (Beta) Power for O2
        original_data = ch_o2_denoised;
        detrended = DataFilter.detrend(original_data, int32(DetrendOperations.LINEAR));
        [ampls, freqs] = DataFilter.get_psd_welch(detrended, nfft, nfft / 2, fs, int32(WindowFunctions.HANNING));
        ch_o2_feature_alpha_power = DataFilter.get_band_power(ampls, freqs, 8.0, 13.0);
        ch_o2_feature_beta_power = DataFilter.get_band_power(ampls, freqs, 14.0, 30.0);

        % 5: Translation Algorithm
        % - Algorithm 1: Alpha Power > Beta Power = Close
        % If beta power is higher than alpha power, it will return 1. In our label, 1 means eyes open and 0 means eyes closed.
        ch_o1_label_predicted = ch_o1_feature_alpha_power < ch_o1_feature_beta_power;
        ch_o2_label_predicted = ch_o2_feature_alpha_power < ch_o2_feature_beta_power;

        % 6: Device/Application
        if ch_o1_label_predicted == 0
            fprintf('O1 Eyes Close | ');
        else
            fprintf('O1 Eyes Open | ');
        end
        if ch_o2_label_predicted == 0
            fprintf('O2 Eyes Close\n\n');
        else
            fprintf('O2 Eyes Open\n\n');
        end

    end
    
    board_shim.stop_stream();
    board_shim.release_session();
    sound(sin(0:3000)); % play stop beep sound for 3s
    DataFilter.write_file(data_save, file_name, 'w');
    disp('---Data Collection Completed---');

catch ME
    board_shim.stop_stream();
    board_shim.release_session();
    disp(ME)
end    



