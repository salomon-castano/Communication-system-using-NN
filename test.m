% clearvars;
test_set = '30_p';
net_name = 'cnnff_40_p';

file = ['Data/train_' test_set '.mat'];
load(file,'data_set','sim_set','step','ss')
load(['Data/' net_name], 'net')

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
predictions_flat = reshape(predictions{:,1}(:,ss/2:ss:end)', [], 1);

for j = 1:length(error_net)
range = [plot_step*(j-1), min(plot_step*j-1, max_range)];
i_min = floor((range(1))/span*len/step)*step + 1;
i_max = ceil((range(2))/span*len/step + 1)*step;

i = i_min:i_max;
i_flat = (i_min-1)*samples+1:i_max*samples;

error_net(j) = sum(predictions_flat(i_flat)...
    ~= labels(i_flat))/length(i_flat);
error_fir(j) = mean(data_set.SER(i));
error_sim(j) = mean(sim_set.SER(i));
end
%% Plots

SNR = min_range:plot_step:max_range;

figure
semilogy(SNR, error_net/4, SNR, error_fir/4, SNR, error_sim/4) %, ...
%     SNR, 2/3*qfunc(sqrt(3*10.^(SNR/10)/15)))
% xlim([0, 25])
% ylim([1e-4, 1])
xlabel('SNR (dB)')
ylabel('BER')
% title(['test set: ' strrep(test_set, '_',' ')])
legend(['Net: ' strrep(net_name, '_',' ')],'FIR decoder',...
    'Simulation of FIR decoder')

SNR_cut = 20;
index = floor((len-1)*(SNR_cut+1)/span) + 1;
figure
plot(predictions{index,1})
hold on
plot(repelem(data_set.labels(index,:), ss))
hold off
ylabel('QAM symbol')
xlabel('Sample')
legend('Prediction', 'Label')
title('SNR = '+string(data_set.SNR(index)))

% figure
% plotconfusion(predictions_flat, labels)
% set(findobj(gca,'type','text'),'fontsize',6)
% title(['test set: ' strrep(test_set, '_',' ')])