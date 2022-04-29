clearvars;
load('Data/cnn_40.mat','net')
load('Data/train_0_30_100','data_set','sim_set','step','ss')

plot_step = 2;

min_range = data_set.SNR(1);
max_range = data_set.SNR(end);
len = size(data_set.data,1);
samples = size(data_set.labels,2);
span = (max_range - min_range + 1);

labels = reshape(data_set.labels', [], 1);
error_net = zeros(ceil(span/plot_step),1);
error_fir = error_net;
error_sim = error_net;

data = cell(len,1);

for i = 1:len
    data{i} = [real(data_set.data(i,:)); imag(data_set.data(i,:))];
end

predictions = net.classify(data);
predictions = cell2table(predictions);
predictions = reshape(predictions{:,1}(:,ss/2:ss:end)', [], 1);

for j = 1:length(error_net)
range = [plot_step*(j-1), min(plot_step*j-1, max_range)];
i_min = floor((range(1) - min_range)/span*len/step)*step + 1;
i_max = ceil((range(2) - min_range)/span*len/step + 1)*step;

i = i_min:i_max;
i_flat = (i_min-1)*samples+1:i_max*samples;

error_net(j) = sum(predictions(i_flat) ~= labels(i_flat))/length(i_flat);
error_fir(j) = mean(data_set.SER(i));
error_sim(j) = mean(sim_set.SER(i));
end
%% Plots

SNR = min_range:plot_step:max_range;

figure
semilogy(SNR, error_net/4, SNR, error_fir/4, SNR, error_sim/4) %, ...
%     SNR, 2/3*qfunc(sqrt(3*10.^(SNR/10)/15)))
xlim([0, 30])
ylim([1e-4, 1])
xlabel('SNR (dB)')
ylabel('BER')
legend('CNN','Correlation decoder', 'Simulation of correlation decoder')

% figure
% plotconfusion(predictions, labels)
% set(findobj(gca,'type','text'),'fontsize',6)