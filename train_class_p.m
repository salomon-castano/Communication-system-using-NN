classdef train_class_p
properties
   
    % default values
    mlen = randi([10,20],1); % length of the message in QAM symbols
    fc = 868e6;       % carrier frequency in Hz
    rb = 50e3;        % symbols (bits) per second
    ss = 8;           % samples per symbol
    fco = 1;          % normalized cutoff frequency 
    QAM = 4;          % size of QAM constellation
    plen = 26;        % preamble length
    fshift = 0;       % frequency shift (simulation)
    pshift = 0;       % phase shift (simulation)
    filter = 'COS';   % type of filter 
    SNR = 20;         % Signal to noise ratio
    setlen = 100;     % length of the trainig set (num of examples) 
    amp               % amplitude of the QAM constellation
    fs                % samples per frame
    rs                % samples per second
    flen              % FIR filters length
    preamble          % preamble
    
    % dependable variables and System Objects
    
    preamble_maker
    txRawFilter
    rxRawFilter
    tx
    rx
    spectrum
    pfo
    channel
    syntonize
    preamble_detector
    m_mean
    m_std
   
end
methods
function a = setup(a) 
  
    % dependable var and System Objects initicalization

    a.amp = ceil(sqrt(a.QAM)-1); % amplitude of the QAM constellation
            
    a.rs = a.ss*a.rb;   % samples per second
          
    a.preamble_maker = comm.BarkerCode('SamplesPerFrame',...
    a.plen, 'Length',13); 
   
    if a.QAM > 2
       a.preamble = a.amp*complex(a.preamble_maker(),...
           fliplr(a.preamble_maker()')');
    else
       a.preamble = a.preamble_maker();
    end
   
    % samples per frame
    a.fs = (2*a.plen + 2*a.mlen)*a.ss;
    
    if strcmp(a.filter,'FIR')
            
        a.flen = a.ss*8;        % FIR filters length
        
        a.txRawFilter = dsp.FIRInterpolator('InterpolationFactor',...
             a.ss,'Numerator', firpm(2*a.flen,[0 a.fco/a.ss, ...
             2*a.fco/a.ss, 1], [1 1 0 0], [1 1]));
                    
        a.rxRawFilter = dsp.FIRDecimator('DecimationFactor', a.ss,...
            'Numerator', firpm(2*a.flen,[0 a.fco/a.ss 2*a.fco/a.ss,...
            1], [1 1 0 0], [1 1]));

    elseif strcmp(a.filter,'COS')
    
        a.flen = a.ss/2;

        a.txRawFilter = comm.RaisedCosineTransmitFilter( ...
            'OutputSamplesPerSymbol',a.ss,...
            'FilterSpanInSymbols',1);
        
        a.rxRawFilter = comm.RaisedCosineReceiveFilter(...
            'InputSamplesPerSymbol',a.ss,'DecimationFactor',a.ss,...
            'FilterSpanInSymbols',1);
    else
        error('Filter type %s is not supported', a.filter)
    end

%     warning('off','plutoradio:sysobj:FirmwareIncompatible');
    warning('off','plutoradio:sysobj:FirmwareIncompatible');
                
    a.tx = sdrtx('Pluto', 'CenterFrequency', a.fc,...
        'BasebandSampleRate', a.rs);

    a.rx = sdrrx('Pluto', 'CenterFrequency', a.fc - a.fshift,...
        'BasebandSampleRate', a.rs, 'GainSource', ...
        'Manual', 'SamplesPerFrame',...
        a.fs, 'OutputDataType', 'single');

%     a.spectrum = dsp.SpectrumAnalyzer(...
%         'Name', 'Spectrum Analyzer Modulated',...
%         'Title', 'Spectrum Analyzer Modulated',...
%         'SpectrumType', 'Power',...
%         'FrequencySpan', 'Full',...
%         'SampleRate', a.rs);
                          
    a.syntonize = comm.CoarseFrequencyCompensator(...
        'SampleRate',a.rs, 'FrequencyResolution',1);
    
    a.preamble_detector = comm.PreambleDetector(a.txFilter(...
        a.preamble), 'Threshold', 3,'Detections','All');
                
   % simulation Ojects
   % Increase frequency offset and phase offset to degrade signal
   a.pfo = comm.PhaseFrequencyOffset('PhaseOffset', a.pshift,...
       'FrequencyOffset', a.fshift, 'SampleRate',a.rs);
   % Decrease EbNo to degrade signal
   a.channel=comm.AWGNChannel('SamplesPerSymbol',a.ss,'EbNo',a.SNR);
    
end

function signal_out = propagate(a, signal_in)

    signal_whole = signal_in;
    signal_tx = a.txFilter(signal_whole);
    signal_out = signal_tx;
    a.tx.Gain = min(a.SNR - 89.75, 0);         % transmitter gain 87 ideal
    a.rx.Gain = ceil(min(89.75 - a.SNR, 71));  % receiver gain (dB)
    % transmits signal
    evalc('a.tx.transmitRepeat(signal_tx)');
    
    % receives signal
    for k=1:7
        evalc('a.rx()');
    end 
    evalc('signal_out = a.rx()');
  
end

function signal_out = simulate(a, signal_in)
    
    a.channel.EbNo = a.SNR;
    signal_whole = [signal_in; signal_in];
    signal_tx = a.txFilter(signal_whole);
    signal_tx = circshift(signal_tx, randi([0,a.fs],1));
    
    % received signal
    signal_out = a.channel(a.pfo(signal_tx));
  
end

function [signal_scaled, signal_cond, phase_offset] = ...
        conditioning(a, signal_out)
  
%     signal_out = a.syntonize(signal_out);
    
    % locating the preamble
    [~, correlation] = a.preamble_detector(signal_out);
    [~, index1] = maxk(correlation, 4*a.ss);
            
    align = mod(index1(1), a.ss);
    index = int32((index1 - align)/a.ss);
    signal_aligned = circshift(signal_out, - align);
    signal_filtered = a.rxFilter(signal_aligned);
        
    i = 1;
    while not(index(i) + a.mlen <= length(signal_out)/a.ss && ...
            index(i)+1 - a.plen  >= 1)
        i = i + 1;
        if i >=  4*a.ss
            index(i) = a.plen;
        end
    end
    data_end = index(i) + a.mlen;
    data_start = index(i) + 1;
    preamble_start = data_start - a.plen;
                     
    % phase correction 2.0

    preamble_aligned = signal_aligned(a.ss*(preamble_start-1)+1:...
        a.ss*(data_start-1));
    preamble_filtered = a.rxFilter(preamble_aligned);
    
    phase_offset = mean(exp(1i*(angle(a.preamble(...
        3:end-2)) - angle(preamble_filtered(3:end-2)))));
    signal_sync = signal_aligned(a.ss*(preamble_start-1)+1:a.ss*data_end)...
        *phase_offset;
    signal_syncf = signal_filtered(preamble_start:data_end)*phase_offset;

    signal_mean = mean(signal_syncf);
    signal_std = std(signal_syncf);

    signal_cond = a.m_std*(signal_syncf-signal_mean)/signal_std+a.m_mean;
    signal_scaled = a.m_std*(signal_sync-signal_mean)/signal_std+a.m_mean;
    
%     signal_cond = a.rxFilter(signal_scaled);
    
end 

function message_out = decode(a, signal)
  
    z = dec2base(qamdemod(signal,a.QAM), a.QAM);
    z = reshape(z, int32(8/log2(a.QAM)), [])';
    message_out = char(base2dec(z,a.QAM))';
  
end

function signal_out = txFilter(a, signal)
    % sets the initial conditions for the filter
    a.txRawFilter(signal(end - ceil(a.flen/a.ss):end)); 
    signal_filtered = a.txRawFilter(signal);
    signal_aligned =  circshift(signal_filtered, -a.flen);
    signal_out = signal_aligned/max(abs(signal_aligned));
end

function signal_out = rxFilter(a, signal)
    % sets the initial conditions for the filter
    signal_aligned = circshift(signal, -a.flen);
    a.rxRawFilter(signal_aligned(end - ceil(a.flen/a.ss)*a.ss + 1:end));
    signal_filtered = a.rxRawFilter(signal_aligned);
    signal_out = signal_filtered; %/max(abs(signal_filtered));
end
        
function release(a)
      
    release(a.tx)
    release(a.rx)
    release(a.pfo)
    release(a.channel)
    release(a.syntonize)
    release(a.preamble_detector)
      
  end         
end
end