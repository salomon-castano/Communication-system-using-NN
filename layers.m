layer = [sequenceInputLayer(2, "MinLength",6)
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
%%
layer_m = [sequenceInputLayer(2, "MinLength",6)
    convolution1dLayer(3,32,"Padding","same")
    reluLayer
    maxPooling1dLayer(3,"Padding","same","Stride",3)
    convolution1dLayer(3,64,"Padding","same")
    reluLayer
    maxPooling1dLayer(2,"Padding","same","Stride",2)
    convolution1dLayer(3,128,"Padding","same")
    dropoutLayer(0.5)
    reluLayer
    transposedConv1dLayer(6,16,"Cropping","same","Stride",6)
    softmaxLayer
    classificationLayer];
%%

layers_f = [sequenceInputLayer(2, "MinLength",6)
    convolution1dLayer(3,32,"Padding","same")
    reluLayer
    maxPooling1dLayer(2,"Padding","same","Stride",2)
    convolution1dLayer(3,64,"Padding","same")
    reluLayer
    maxPooling1dLayer(3,"Padding","same","Stride",3)
    convolution1dLayer(3,128,"Padding","same")
    dropoutLayer(0.5)
    reluLayer
    transposedConv1dLayer(6,32,"Cropping","same","Stride",6)
    fullyConnectedLayer(16)
    softmaxLayer
    classificationLayer];

%%
layers_ff = [sequenceInputLayer(2, "MinLength",6)
    convolution1dLayer(3,64,"Padding","same")
    reluLayer
    maxPooling1dLayer(2,"Padding","same","Stride",2)
    convolution1dLayer(3,128,"Padding","same")
    reluLayer
    maxPooling1dLayer(3,"Padding","same","Stride",3)
    convolution1dLayer(3,256,"Padding","same")
    dropoutLayer(0.5)
    reluLayer
    transposedConv1dLayer(6,32,"Cropping","same","Stride",6)
    fullyConnectedLayer(16)
    fullyConnectedLayer(16)
    softmaxLayer
    classificationLayer];

%%
layers_c = [sequenceInputLayer(2, "MinLength",6)
    convolution1dLayer(3,32,"Padding","same")
    reluLayer
    convolution1dLayer(3,32,"Padding","same")
    reluLayer
    maxPooling1dLayer(2,"Padding","same","Stride",2)
    convolution1dLayer(3,64,"Padding","same")
    reluLayer
    convolution1dLayer(3,64,"Padding","same")
    reluLayer
    maxPooling1dLayer(3,"Padding","same","Stride",3)
    convolution1dLayer(3,128,"Padding","same")
    dropoutLayer(0.5)
    reluLayer
    convolution1dLayer(3,128,"Padding","same")
    reluLayer
    transposedConv1dLayer(6,16,"Cropping","same","Stride",6)
    softmaxLayer
    classificationLayer];

%%
layers_t = [sequenceInputLayer(2, "MinLength",6)
    convolution1dLayer(3,32,"Padding","same")
    reluLayer
    maxPooling1dLayer(2,"Padding","same","Stride",2)
    convolution1dLayer(3,64,"Padding","same")
    reluLayer
    maxPooling1dLayer(3,"Padding","same","Stride",3)
    convolution1dLayer(3,128,"Padding","same")
    dropoutLayer(0.5)
    reluLayer
    transposedConv1dLayer(3,64,"Cropping","same","Stride",3)
    reluLayer
    transposedConv1dLayer(2,32,"Cropping","same","Stride",2)
    reluLayer
    transposedConv1dLayer(1,16,"Cropping","same","Stride",1)
    softmaxLayer
    classificationLayer];
% %%
% layers_tt = [sequenceInputLayer(2, "MinLength",6)
%     convolution1dLayer(3,32,"Padding","same")
%     reluLayer('Name', 'relu_1')
%     maxPooling1dLayer(2,"Padding","same","Stride",2)
%     convolution1dLayer(3,64,"Padding","same")
%     reluLayer
%     maxPooling1dLayer(3,"Padding","same","Stride",3)
%     convolution1dLayer(3,128,"Padding","same")
%     dropoutLayer(0.5)
%     reluLayer
%     transposedConv1dLayer(6,32,"Cropping","same","Stride",6)
%     additionLayer(2,"Name","addition")
%     convolution1dLayer(3,16,"Padding","same")
%     softmaxLayer
%     classificationLayer];
% 
% lgraph = layerGraph();
% lgraph = addLayers(lgraph, layers_tt);
% layers_tt = connectLayers(lgraph,"relu_1","addition/in2");

%%
layers_tf = [sequenceInputLayer(2, "MinLength",6)
    convolution1dLayer(3,32,"Padding","same")
    reluLayer('Name', 'relu_1')
    maxPooling1dLayer(2,"Padding","same","Stride",2)
    convolution1dLayer(3,64,"Padding","same")
    reluLayer
    maxPooling1dLayer(3,"Padding","same","Stride",3)
    convolution1dLayer(3,128,"Padding","same")
    reluLayer
    transposedConv1dLayer(6,32,"Cropping","same","Stride",6)
    additionLayer(2,"Name","addition")
    dropoutLayer(0.5)
    reluLayer
    convolution1dLayer(3,16,"Padding","same")
    reluLayer
    fullyConnectedLayer(16)
    softmaxLayer
    classificationLayer];

lgraph = layerGraph();
lgraph = addLayers(lgraph, layers_tf);
layers_tf = connectLayers(lgraph,"relu_1","addition/in2");
plot(layers_tf)
