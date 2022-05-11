close ('all'); %clearvars;
%% Initialization parameters
% net_name = 'cnnff_40_p';
% load(['Data/' net_name], 'net')

% message to be transmitted
fileID = fopen('message.txt');
message = fread(fileID,'*char')';
fclose(fileID);

a = FD_class();
a.QAM = 16;          % size of QAM constellation
a.fc = 868e6;        % carrier frequency in Hz
a.rb = 800e3;        % symbols (bits) per second
a.ss = 6;            % samples per symbol
a.plen = 1*26;       % preamble length must be multiple of 2
a.SNR = 40;          % transmitter gain (dB) channel limit: -73 dB
a.filter = 'FIR';    % type of filter FIR or COS
a.fshift = 0;        % frequency shift (simulation)
a.pshift = 152;        % phase shift (simulation)
a = a.setup(message);

%% Propagation

signal_in = a.encode(message); % encodes the message
a.m_mean = mean(signal_in);
a.m_std = std(signal_in);

signal_out = a.propagate(signal_in); % transmits and receives the signal

%% Processing

% syncronizes and aligns the received signal and finds preamble
[signal_FD, signal_net, phase_offset] = a.conditioning(signal_out);
preamble_out = a.rxFilter(signal_net(1:a.plen*a.ss));
a.release() % releases system objects

signal_QAM_FD = qamdemod(signal_FD,a.QAM);
message_out_FD = a.decode(signal_QAM_FD); % decodes
errors_FD = sum(message_out_FD ~= message);
message_out_FD
fprintf('Errors FD: %d \n', errors_FD)

% signal_net_s = [real(signal_net)';imag(signal_net)'];
% signal_QAM_net_long = net.classify(signal_net_s)';
% signal_QAM_net = single(signal_QAM_net_long(a.ss*(a.plen+1/2):a.ss:end))-1;
% message_out_net = a.decode(double(signal_QAM_net)); % decodes
% errors_net = sum(message_out_net ~= message);
% fprintf('Errors net: %d \n', errors_net)

% make plots

figure
plot(real(signal_net))
figure
plot(real(preamble_out))
a.spectrum(signal_out)
scatterplot(signal_FD)
scatterplot(preamble_out)
