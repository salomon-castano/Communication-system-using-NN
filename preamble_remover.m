file = 'Data/train_40';
new_name = [file '_f.mat'];

load(file,'data_set','sim_set','step','ss')

new_set = {data_set, sim_set};

for i = 1:2

new_set{i} = removevars(new_set{i},{'data_f'});
new_set{i}.data = new_set{i}.data(:, ss*26+1:end);
new_set{i}.labels = new_set{i}.labels(:, 26+1:end);

end

data_set = new_set{1};
sim_set = new_set{2};

save(new_name,'data_set','sim_set','step','ss')