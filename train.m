close ('all')
load('train_0_40_100.mat','data_set','step','ss')

range = [15, 20];

min_range = data_set.SNR(1);
max_range = data_set.SNR(end);
len = size(data_set.data,1);
i_min =floor((range(1)-min_range)/(max_range-min_range+1)*len/step)*step+1;
i_max = ceil((range(2)-min_range)/(max_range-min_range+1)*len/step+1)*step;
data_set = data_set(i_min:i_max,:);

observations = size(data_set.data,1);

data = cell(observations,1);
labels = cell(observations,1);

for i = 1:observations
    data{i} = [real(data_set.data(i,:)); imag(data_set.data(i,:))];
    labels{i} = repelem(data_set.labels(i,:), ss);
end

[i_test, i_val, i_train] = splitData(observations, 0.2, 0.1);

data_test = data(i_test);
labels_test = reshape(data_set.labels(i_test,:)', [], 1);

data_val = data(i_val);
labels_val = labels(i_val);

data_train = data(i_train);
labels_train = labels(i_train);

%%
maxEpochs = 20;
BatchSize = 64; %ceil(observations/16)*2;

% layers = [
%     sequenceInputLayer(2)
%     bilstmLayer(128)
%     fullyConnectedLayer(16)
%     dropoutLayer(0.5)
%     fullyConnectedLayer(16)
%     softmaxLayer
%     classificationLayer];

layers = [sequenceInputLayer(2, "MinLength",6)
    convolution1dLayer(3,32,"Padding","same")
    reluLayer
    maxPooling1dLayer(2,"Padding","same","Stride",2)
    convolution1dLayer(3,64,"Padding","same")
    reluLayer
    maxPooling1dLayer(3,"Padding","same","Stride",3)
    convolution1dLayer(3,128,"Padding","same")
    dropoutLayer(0.5)
    reluLayer
    transposedConv1dLayer(6,16,"Cropping","same","Stride",6)
    softmaxLayer
    classificationLayer];

options = trainingOptions('adam', ...
    'ExecutionEnvironment','gpu', ...
    'GradientThreshold',1, ...
    'MaxEpochs',maxEpochs, ...
    'MiniBatchSize',BatchSize, ...
    'ValidationFrequency',16, ...
    'ValidationPatience',10, ...
    'ValidationData',{data_val, labels_val}, ...
    'Verbose',0, ...
    'Plots','training-progress');

net = trainNetwork(data_train, labels_train, layers, options);
%% Error

predictions = classify(net, data_test);
predictions = cell2table(predictions);
predictions_flat = reshape(predictions{:,1}(:,ss/2:ss:end)', [], 1);

error_net = sum(predictions_flat ~= labels_test)/length(predictions_flat)
error_fir = mean(data_set.SER(i_test))

cut = 1;
index = i_test(floor((end-1)*cut)+1);
figure
plot(predictions{floor((end-1)*cut)+1,1})
hold on
plot(repelem(data_set.labels(index,:), ss))
hold off
ylabel('QAM symbol')
xlabel('Sample')
legend('Predicion', 'Label')
title('SNR = '+string(data_set.SNR(index)))

figure
plotconfusion(predictions_flat, labels_test)
set(findobj(gca,'type','text'),'fontsize',6)