close ('all'); %clearvars;
%% Initialization parameters

a = DSP_class();
a.fc = 900e6;       % carrier frequency in Hz
a.rb = 30e3;        % symbols (bits) per second
a.ss = 10;          % samples per symbol
a.fs = 6e3;         % samples per frame
a.QAM = 2;          % size of QAM constellation
a.guard = 400;      % guard length
a.delay = 500;      % approximate delay of the transmitter
a = a.setup();

%% Execution
message = 'For whoever is slowing down the pc I wish they suffer';     % message to be transmitted

signal_in = a.encode(message); % encodes the message
scatterplot(signal_in)
signal_out = a.propagate(signal_in); % transmits and receives the signal

[signal, message_out] = a.decode(signal_out); % receives and decodes

plot(10*log10(abs(signal)))

sprintf(message_out)
a.release() % releases system objects
scatterplot(signal)
