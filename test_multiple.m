% clearvars;
test_set = '30_p';
net_name = {'cnn_40_p', 'cnnf_40_p','cnnc_40_p', 'cnntt_40_p',...
    'cnnff_40_p'};

file = ['Data/train_' test_set '.mat'];
load(file,'data_set','sim_set','step','ss')

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
error_nets = containers.Map(net_name, cell(1,length(net_name)));
for k = 1:length(net_name)
    load(['Data/' net_name{k}], 'net')
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
    error_nets(net_name{k}) = error_net;
end
%% Plots

SNR = min_range:plot_step:max_range;

figure
legend_i = 'FIR decoder';
semilogy(SNR, error_fir/4, 'DisplayName', legend_i)
hold on
legend_i = 'Simulation of FIR decoder';
semilogy(SNR, error_sim/4, 'DisplayName', legend_i)
% semilogy(SNR, 2/3*qfunc(sqrt(3*10.^(SNR/10)/15)))

for i = 1:length(net_name)
    legend_i = ['Net: ' strrep(net_name{i}, '_',' ')];
    semilogy(SNR, error_nets(net_name{i})/4, 'DisplayName', legend_i)
end
% xlim([0, 25])
% ylim([1e-4, 1])
xlabel('SNR (dB)')
ylabel('BER')
% title(['test set: ' strrep(test_set, '_',' ')])
hold off
legend('Location','southwest')


% SNR_cut = 20;
% index = floor((len-1)*(SNR_cut+1)/span) + 1;
% figure
% plot(predictions{index,1})
% hold on
% plot(repelem(data_set.labels(index,:), ss))
% hold off
% ylabel('QAM symbol')
% xlabel('Sample')
% legend('Prediction', 'Label')
% title('SNR = '+string(data_set.SNR(index)))

% figure
% plotconfusion(predictions_flat, labels)
% set(findobj(gca,'type','text'),'fontsize',6)
% title(['test set: ' strrep(test_set, '_',' ')])