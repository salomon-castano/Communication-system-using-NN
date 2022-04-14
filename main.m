close ('all'); %clearvars;
%% Initialization parameters

% message to be transmitted
message = 'Once upon time there was a devil devil class called DSP';

a = DSP_class();
a.fc = 868e6;       % carrier frequency in Hz
a.rb = 50e3;        % symbols (bits) per second
a.ss = 8;           % samples per symbol
a.QAM = 4;          % size of QAM constellation
a.plen = 1*26;      % preamble length must be multiple of 2
a.delay = 50;      % approximate delay of the transmitter (simulation)
a = a.setup(message);

%% Propagation

signal_in = a.encode(message); % encodes the message
signal_out = a.propagate(signal_in); % transmits and receives the signal

%% Processing

% syncronizes and aligns the received signal and finds preamble
[preamble_cond, signal_cond] = a.conditioning(signal_out); 

message_out = a.decode(signal_cond); % decodes

a.release() % releases system objects

% make plots
sprintf(message_out)
figure(1)
plot(real(preamble_cond))
figure(2)
plot(imag(signal_out))
scatterplot(signal_cond)
