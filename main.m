close ('all'); %clearvars;
%% Initialization parameters

% message to be transmitted
message = '123 abc xyz #$%';

a = DSP_class();
a.fc = 868e6;       % carrier frequency in Hz
a.rb = 50e3;        % symbols (bits) per second
a.ss = 8;           % samples per symbol
a.QAM = 4;          % size of QAM constellation
a.plen = 1*26;      % preamble length must be multiple of 2
a.delay = 100;      % approximate delay of the transmitter (simulation)
a = a.setup(message);

%% Propagation

signal_in = a.encode(message); % encodes the message

signal_o = a.propagate(signal_in); % transmits and receives the signal
signal_o = signal_o/max(abs(signal_o));

%% Processing

signal_sync = a.syntonize(signal_o);
signal_sync = a.synchronize(signal_sync);

[~, corr] = a.slope_detector(imag(signal_sync));
[~, ind] = max(corr);
ind = mod(ind - a.ss/2, a.ss);
signal_out = signal_o(1+ind:end+ind-a.ss);


% signal_out1 = signal_out(1:a.plen*a.ss);
% signal_outFilter = abs(a.rxFilter(signal_out1));
% signal_outFilter = signal_outFilter/max(signal_outFilter);
% signal_outFIR = abs(a.rxFilter(signal_out1));
% signal_outFIR = signal_outFIR/max(signal_outFIR);
% 
% if std(1./signal_outFilter) < std(1./signal_outFIR)
%     signal_out2 = a.rxFilter(signal_out);
% else
%     signal_out2 = 2*a.rxFIR(signal_out);
% end

signal_out2 = 2*a.rxFIR(signal_out);

% syncronizes the signal received and finds preamble
[preamble_cond, signal_cond] = a.conditioning(signal_out2); 

message_out = a.decode(signal_cond); % decodes

a.release() % releases system objects

% make plots
sprintf(message_out)
figure(1)
plot(real(preamble_cond))
figure(2)
plot(imag(signal_out))
scatterplot(signal_cond)
