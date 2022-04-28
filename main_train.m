close ('all'); %clearvars;
%% Initialization parameters

a = DSP_train();

a.QAM = 16;         % size of QAM constellation
a.fc = 868e6;       % carrier frequency in Hz
a.rb = 800e3;       % QAM symbols per second
a.ss = 6;           % samples per symbol
a.fco = 23/32;      % normalized cutoff frequency for the FIR filters
a.plen = 1*26;      % preamble length must be multiple of 2
a.filter = 'FIR';   % type of filter FIR or COS
a.fshift = 0;     % frequency shift
a.pshift = 180;       % phase shift (simulation)
a.mlen = a.QAM*6;   % length of the message in QAM symbols
step= 100;
a.setlen = 41*step;     % length of the trainig set (num of examples) 
a = a.setup();

data_set = table(zeros(a.setlen,1), zeros(a.setlen,1), zeros(a.setlen,...
    a.fs/2), categorical(zeros(a.setlen, a.mlen+a.plen)), zeros(a.setlen,...
    a.mlen+a.plen));
data_set.Properties.VariableNames = {'SNR','SER','data','labels','data_f'};
noise_set = table(zeros(ceil(a.setlen/8),1), zeros(ceil(a.setlen/8),1));
noise_set.Properties.VariableNames = {'SNR','SER'};
preambleQAM = qamdemod(a.preamble,a.QAM);

%% Propagation
j = 0;
k = 0;
data_set.SER(1) = 1;
fprintf("Iteration:     SER:\n")
while j < a.setlen
a.SNR = floor(j/step);         % signal to noise ration

% message to be transmittedin QAM symbols
messageQAM =  [preambleQAM; randi([0, a.QAM-1],[a.mlen, 1])];
signal_in = qammod(messageQAM, a.QAM);
a.m_mean = mean(signal_in);
a.m_std = std(signal_in);
% Propagation

signal_out = a.propagate(signal_in); % transmits and receives the signal

%% Processing

% syncronizes and aligns the received signal and finds preamble
[signal_scaled, signal_cond, phase_offset] = a.conditioning(signal_out); 
messageQAM_out = qamdemod(signal_cond,a.QAM);

SER =sum(messageQAM_out ~= messageQAM)/(a.mlen+a.plen);
release(a.tx)
release(a.rx)

if SER < max(min(min(1.55-(a.SNR+0)/17, 1.06-(a.SNR)/40),0.96), 0.04)
    j = j + 1;
    data_set.data(j,:) = signal_scaled';
    data_set.data_f(j,:) = signal_cond';
    data_set.labels(j,:) = categorical(messageQAM');
    data_set.SER(j) = SER;
    data_set.SNR(j) = a.SNR;
    fprintf(string(j)+"              "+string(SER)+"\n")
else
    fprintf('SER was too big (%s) the results will not be saved\n', SER)
    k = k +1;
    noise_set.SER(k) = SER;
    noise_set.SNR(k) = a.SNR;
    pause(1)
end
end
noise_set = noise_set(1:k,:);

a.release(); % releases system objects

%% Postprocessing

% figure
% plot(real(preamble_cond))
% figure
% plot(real(signal_out*phase_offset))
% scatterplot(signal_cond)
% a.spectrum([signal_out;signal_out;signal_out])
% figure
% scatter(messageQAM, messageQAM_out,'filled')
% scatterplot(signal_cond)
figure
scatter(data_set.SNR,data_set.SER,'filled')
hold on
scatter(sim_set.SNR,sim_set.SER)
scatter(noise_set.SNR,noise_set.SER,'cyan')
plot(data_set.SNR,max(min(min(1.55-(data_set.SNR+0)/17, ...
    1.06-(data_set.SNR)/40), 0.96), 0.04))
hold off
ss = a.ss;