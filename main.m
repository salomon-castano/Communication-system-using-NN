close ('all'); clearvars;
%% Initialization parameters

% message to be transmitted
message = 'Salo 123 xyz Salomón Castaño Carvajal Bardawil Posada Henao Amar Vallejo';

a = DSP_class();
a.QAM = 16;          % size of QAM constellation
a.fc = 868e6;        % carrier frequency in Hz
a.rb = 800e3;        % symbols (bits) per second
a.ss = 8;           % samples per symbol
a.fco = 23/32;       % normalized cutoff frequency for the FIR filters
a.fspan = 4;        % Raised cosine filter span in symbols
a.plen = 1*26;      % preamble length must be multiple of 2
a.filter = 'FIR';   % type of filter FIR or COS
a.txGain = -20;     % transmitter gain (dB) channel limit: -73 dB
a.fshift = 0;       % frequency shift (simulation)
a.pshift = 180;       % phase shift (simulation)
a = a.setup(message);

%% Propagation

signal_in = a.encode(message); % encodes the message

% messageQAM = randi([0, a.QAM-1],[a.mlen, 1]);
% signal_in = qammod(messageQAM, a.QAM);

signal_out = a.propagate(signal_in); % transmits and receives the signal

%% Processing

% syncronizes and aligns the received signal and finds preamble
[preamble_cond, signal_cond, phase_offset] = a.conditioning(signal_out); 

message_out = a.decode(signal_cond); % decodes

a.release() % releases system objects

% make plots
sprintf(message_out)
figure
plot(real(preamble_cond))
figure
plot(real(signal_out*phase_offset))
a.spectrum(signal_out)
scatterplot([preamble_cond;signal_cond])
