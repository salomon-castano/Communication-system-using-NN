close ('all')
load('train_0_40_100.mat','data_set','step','ss')

range = [0,40];

min_range = data_set.SNR(1);
max_range = data_set.SNR(end);
len = size(data_set.data,1);
i_min = floor((range(1)-min_range)/(max_range-min_range)*len/step)*step+1;
i_max =  ceil((range(2)-min_range)/(max_range-min_range)*len/step)*step;
data_set = data_set(i_min:i_max,:);

observations = size(data_set.data,1);
samples = size(data_set.data,2);

data = cell(observations,1);
labels = cell(observations,1);

for i = 1:observations
    data{i} = [real(data_set.data(i,:)); imag(data_set.data(i,:))];
    labels{i} = repelem(data_set.labels(i,:), ss);
%     labels{i} = data_set.labels(i,:);
end

[i_test, i_val, i_train] = splitData(observations, 0.2, 0.1);

data_test = data(i_test);
labels_test = labels(i_test);

data_val = data(i_val);
labels_val = labels(i_val);

data_train = data(i_train);
labels_train = labels(i_train);

%%
maxEpochs = 2;
BatchSize = 1; %ceil(observations/16)*2;

layers = [
    sequenceInputLayer(2)
    bilstmLayer(128)
    fullyConnectedLayer(16)
    dropoutLayer(0.5)
    fullyConnectedLayer(16)
    softmaxLayer
    classificationLayer];

options = trainingOptions('adam', ...
    'ExecutionEnvironment','gpu', ...
    'GradientThreshold',1, ...
    'MaxEpochs',maxEpochs, ...
    'MiniBatchSize',BatchSize, ...
    'ValidationFrequency',16, ...
    'ValidationPatience',4, ...
    'ValidationData',{data_val, labels_val}, ...
    'Verbose',0, ...
    'Plots','training-progress');

net = trainNetwork(data_train, labels_train, layers, options);
%%
error = 0;
for i = 1:length(data_test)
    datai = classify(net, data_test{i});
    error = error + sum(datai(ss/2:ss:end) ~= labels_test{i}(ss/2:ss:end));
end
error_net = error/(length(data_test)*samples/ss)
error_fir = mean(data_set.SER(i_test))
