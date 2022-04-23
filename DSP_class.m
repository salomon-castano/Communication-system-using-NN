classdef DSP_class
properties
   
    % default values
    fc = 868e6;       % carrier frequency in Hz
    rb = 50e3;        % symbols (bits) per second
    ss = 8;           % samples per symbol
    fco = 1;          % normalized cutoff frequency 
    QAM = 4;          % size of QAM constellation
    plen = 26;        % preamble length
    fshift = 0;       % frequency shift (simulation)
    pshift = 0;       % phase shift (simulation)
    filter = 'COS';   % type of filter 
    amp               % amplitude of the QAM constellation
    fs                % samples per frame
    rs                % samples per second
    ls                % symbols per letter
    mlen              % message length
    flen              % FIR filters length
    preamble          % preamble
    
    % dependable variables and System Objects
    
    preamble_maker
    txRawFilter
    rxRawFilter
    tx
    rx
    pfo
    channel
    syntonize
    synchronize
    preamble_detector
   
end
methods
function a = setup(a, message) 
  
    % dependable var and System Objects initicalization
            
    a.rs = a.ss*a.rb;   % samples per second
    
    a.ls = int32(8/log2(a.QAM)); %symbols per letter
    
    a.mlen = length(message)*a.ls; % message length in QAM symbols
          
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
                
    a.tx = sdrtx('Pluto', 'CenterFrequency', a.fc,...
        'BasebandSampleRate', a.rs, 'Gain', -20);

    a.rx = sdrrx('Pluto', 'CenterFrequency', a.fc,...
        'BasebandSampleRate', a.rs, 'GainSource', ...
        'Manual', 'Gain', 20, 'SamplesPerFrame',...
        a.fs, 'OutputDataType', 'single');
                          
    a.syntonize = comm.CoarseFrequencyCompensator(...
        'SampleRate',a.rs, 'FrequencyResolution',1);
    
    a.synchronize = comm.CarrierSynchronizer( ...
        'SamplesPerSymbol',a.ss);
    
    a.preamble_detector = comm.PreambleDetector(a.txFilter(...
        a.preamble), 'Threshold', 3,'Detections','All');
                
   % simulation Ojects
   % Increase frequency offset and phase offset to degrade signal
   a.pfo = comm.PhaseFrequencyOffset('PhaseOffset', a.pshift,...
       'FrequencyOffset', a.fshift, 'SampleRate',a.rs);
   % Decrease EbNo to degrade signal
   a.channel=comm.AWGNChannel('SamplesPerSymbol',a.ss,'EbNo',50);
    
end

function signal_in = encode(a, message)
  
    % encodes the message into a vector using ASCII in base a.QAM
    m = dec2base(message, a.QAM, a.ls);
    m = reshape(m', numel(m), []);
    signal_dec = base2dec(m, a.QAM);
    
    % applies QAM mapping
    QAM_signal = qammod(signal_dec, a.QAM);
    
    % inerpolation and optimal filter for ISI
    signal_in = QAM_signal;    
  
end

function signal_out = propagate(a, signal_in)

    signal_whole = [a.preamble; signal_in];
    signal_tx = a.txFilter(signal_whole);
    
    % transmits signal
    a.tx.transmitRepeat(signal_tx);
    
    % receives signal
    signal_out = a.rx();
  
end

function signal_out = simulate(a, signal_in)
  
    signal_whole = [a.preamble; signal_in; a.preamble; signal_in];
    signal_tx = a.txFilter(signal_whole);
    signal_tx = circshift(signal_tx, randi([0,a.fs],1));
    
    % received signal
    signal_out = a.channel(a.pfo(signal_tx));
  
end

function [preamble_cond, signal_cond] = conditioning(a, signal_out)
  
%     signal_synt = a.syntonize(signal_out);
%     signal_sync = a.synchronize(signal_synt);
%     signal_out = signal_sync;
    
    % locating the preamble
    [~, correlation] = a.preamble_detector(signal_out);
    [~, index] = maxk(correlation, 8);
            
    align = mod(index(1), a.ss);
    index = int32((index - align)/a.ss);
    signal_aligned = circshift(signal_out, - align);
    signal_filtered = a.rxFilter(signal_aligned);
    
    data_end = index(1) + a.mlen;
    if data_end <= length(signal_filtered) && index(1) - a.plen  > 1
        data_start = index(1) + 1;
    else 
      i = 1;
      while abs(index(i)-index(1)) < a.mlen + a.plen - 1
        i = i + 1;
      end
      data_end = index(i) + a.mlen;
      data_start = index(i) + 1;
    end

    preamble_start = data_start - a.plen;
                     
    % phase correction 2.0
    preamble_filtered = signal_filtered(preamble_start:data_start-1);
    
    phase_offset = (mean(exp(1i*(angle(a.preamble(...
        end-a.plen+1:end)) - angle(preamble_filtered)))));
    signal_sync =signal_filtered.*phase_offset;

    % position correction
    real_shift = max(real(signal_sync)) + min(real(signal_sync));
    imag_shift = max(imag(signal_sync)) + min(imag(signal_sync));

    signal_scaled = signal_sync - (real_shift + 1i*imag_shift)/2;
    signal_cond_whole = a.amp*signal_scaled/max(real(signal_scaled));
    
    signal_cond = signal_cond_whole(data_start:data_end);
    preamble_cond = signal_cond_whole(preamble_start:data_start-1);
    
end 

function message_out = decode(a, signal)
  
    z = dec2base(qamdemod(signal,a.QAM), a.QAM);
    z = reshape(z, a.ls, [])';
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
    signal_out = signal_filtered/max(abs(signal_filtered));
end
        
function release(a)
      
    release(a.tx)
    release(a.rx)
    release(a.pfo)
    release(a.channel)
    release(a.syntonize)
    release(a.synchronize)
    release(a.preamble_detector)
      
  end         
end
end