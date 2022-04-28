close ('all')
load('train_0_28_40.mat','set2')
set = set2(end-ceil(size(set2,1)/8):end,:);
% set = set2;

observations = size(set.data,1);
samples = size(set.data,2);

data = cell(observations,1);
labels = cell(observations,1);

for i = 1:observations
    data{i} = [real(set.data(i,:)); imag(set.data(i,:))];
    labels{i} = categorical(qamdemod(set.labels(i,:),16));
%     data{i,2} = set.labels(i,:);
%     data{i,2} = [real(set.labels(i,:)); imag(set.labels(i,:))];
end

[i_test, i_val, i_train] = splitData(observations, 0.2, 0.1);

data_test = data(i_test);
labels_test = labels(i_test);

data_val = data(i_val);
labels_val = labels(i_val);

data_train = data(i_train);
labels_train = labels(i_train);

%%
maxEpochs = 200;
BatchSize = ceil(observations/16)*2;

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
    error = error + sum(datai ~= labels_test{i});
end
error_net = error/(length(data_test)*samples)
error_fir = mean(set.SER(i_test))
