openBCI_serial_port = '/dev/cu.usbserial-XXXXXXXX'; % For Mac Operating System | Change the serial port accordingly
% openBCI_serial_port = 'COM3'; % For Windows Operating System | Change the serial port accordingly
file_name = 'data/EyesSubject1Session9.csv';
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
board_shim = BoardShim(0, params); % BoardIds.SYNTHETIC_BOARD (-1)  |  BoardIds.CYTON_BOARD (0)

try
    board_shim.prepare_session();
    board_shim.start_stream(450000, '');

    for i_segment = 1:total_trial
        sound(sin(0:300)); % play beep sound for 300ms at the beginning of each 5 seconds window
        if(mod(i_segment,2) == 1)
            disp('Open Your Eyes');
        else
            disp('Close Your Eyes');
        end

        pause(window_size);

        % Signal Acquisition
        data = board_shim.get_board_data(board_shim.get_board_data_count());
        data_save = [data_save data];
        disp(strcat('Elapsed: ', num2str(i_segment*window_size), ' Seconds'));
    end
    disp(length(data_save)/fs)

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


