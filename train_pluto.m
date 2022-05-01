close ('all'); %clearvars;
%% Initialization parameters

a = train_class();

a.QAM = 16;         % size of QAM constellation
a.fc = 868e6;       % carrier frequency in Hz
a.rb = 800e3;       % QAM symbols per second
a.ss = 6;           % samples per symbol
a.fco = 23/32;      % normalized cutoff frequency for the FIR filters
a.plen = 1*26;      % preamble length must be multiple of 2
a.filter = 'FIR';   % type of filter FIR or COS
a.fshift = 0;     % frequency shift
a.pshift = 123;       % phase shift (simulation)
a.mlen = a.QAM*6;   % length of the message in QAM symbols
ds = -1;
step = 100;
a.setlen = 2*step;     % length of the trainig set (num of examples) 
a = a.setup();

data_set = table(zeros(a.setlen,1), zeros(a.setlen,1), zeros(a.setlen,...
    a.mlen*a.ss), categorical(zeros(a.setlen, a.mlen)));
data_set.Properties.VariableNames = {'SNR','SER','data','labels'};
noise_set = table(zeros(ceil(a.setlen/8),1), zeros(ceil(a.setlen/8),1));
noise_set.Properties.VariableNames = {'SNR','SER'};
% preambleQAM = qamdemod(a.preamble,a.QAM);

%% Propagation
j = 0;
k = 0;
data_set.SER(1) = 1;
fprintf("\nSER:     SNR:    Progress:\n\n")
while j < a.setlen
a.SNR = 25+floor(j/step);         % signal to noise ration

% message to be transmittedin QAM symbols
messageQAM =  randi([0, a.QAM-1],[a.mlen, 1]);
signal_in = qammod(messageQAM, a.QAM);
a.m_mean = mean(signal_in);
a.m_std = std(signal_in);
% Propagation

signal_out = a.propagate(signal_in); % transmits and receives the signal

%% Processing

% syncronizes and aligns the received signal and finds preamble
[signal_scaled, signal_cond, phase_offset] = a.conditioning(signal_out); 
messageQAM_out = qamdemod(signal_cond,a.QAM);

SER =sum(messageQAM_out ~= messageQAM)/length(messageQAM);

if SER < max(min(min(1.55-(a.SNR+ds)/17, 1.06-(a.SNR-1)/40),0.97), 0.04)
    j = j + 1;
    data_set.data(j,:) = signal_scaled';
    data_set.labels(j,:) = categorical(messageQAM');
    data_set.SER(j) = SER;
    data_set.SNR(j) = a.SNR;
    if mod(j, 20) == 0
        fprintf('%.4f   %02d      %.1f%%\n',SER, a.SNR, 100*j/a.setlen)
    end
else    
    fprintf('%.4f   %02d      %.1f%%  SER too big. Result ignored.\n',...
        SER, a.SNR, 100*j/a.setlen)
    k = k + 1;
    noise_set.SER(k) = SER;
    noise_set.SNR(k) = a.SNR;
    pause(1)
end
end
noise_set = noise_set(1:k,:);

a.release(); % releases system objects

%% Postprocessing

figure
plot(real(signal_out*phase_offset))
scatterplot(signal_cond)
figure
scatter(messageQAM, messageQAM_out,'filled')
% a.spectrum([signal_out;signal_out;signal_out])

figure
scatter(data_set.SNR,data_set.SER,'filled')
hold on
scatter(sim_set.SNR,sim_set.SER)
scatter(noise_set.SNR,noise_set.SER,'cyan')
plot(data_set.SNR,max(min(min(1.55-(data_set.SNR+ds)/17, ...
    1.06-(data_set.SNR-1)/40), 0.97), 0.04))
hold off
ss = a.ss;