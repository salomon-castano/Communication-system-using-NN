function [i_test, i_val, i_train] = splitData(Q,fraction_test,fraction_val)

    Qval = floor(Q*fraction_val); % number of validation samples
    Qtest = floor(Q*fraction_test); % number of test samples
    Qtrain = Q - Qval - Qtest; % '' train samples
    i = randperm(Q); % indices
    i_val = i(1:Qval); % indices for validation
    i_test = i(Qval + (1:Qtest)); % '' testing
    i_train = i(end - Qtrain + 1:end); % '' training
    
end