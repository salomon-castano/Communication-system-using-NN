close ('all'); clearvars;
%% Initialization parameters

% message to be transmitted
message = 'Había una vez una iguana, con una ruana de lana, peinandose';

a = DSP_class();
a.QAM = 16;          % size of QAM constellation
a.amp = sqrt(a.QAM)-1; % amplitude of the QAM constellation
a.fc = 868e6;       % carrier frequency in Hz
a.rb = 50e3/a.amp;  % symbols (bits) per second
a.ss = 8*a.amp;     % samples per symbol
a.fco = 0.72;        % normalized cutoff frequency for the FIR filters
a.plen = 1*26;      % preamble length must be multiple of 2
a.filter = 'FIR';   % type of filter FIR or COS
a.fshift = 0;       % frequency shift (simulation)
a.pshift = 0;       % phase shift (simulation)
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
plot(real(signal_out))
scatterplot(signal_cond)
