classdef DSP_class
   properties
       
       % default values
       fc = 900e6;       % carrier frequency in Hz
       rb = 60e3;        % symbols (bits) per second
       ss = 5;           % samples per symbol
       fs = 5e3;         % samples per frame
       QAM = 4;          % size of QAM constellation
       guard = 100;      % guard length
       delay = 500;      % approximate delay of the transmitter
       rs                % samples per second
       ls                %symbols per letter
       
       % dependable variables and System Objects
       preamble
       txFilter
       rxFilter
       tx
       rx
       pfo
       channel
       syntonize
       synchronize
       preamble_detector
       
   end
   methods
      function a = setup(a) 
            % dependable var and System Objects initicalization
            
            a.rs = a.ss*a.rb;   % samples per second
            
            a.ls = int32(8/log2(a.QAM)); %symbols per letter
          
            a.preamble = comm.BarkerCode('SamplesPerFrame',13,...
               'Length',13); 
           
           if a.QAM > 2
               a.preamble = a.preamble()*complex(1,1);
           else
               a.preamble = a.preamble();
           end
           
            a.txFilter = comm.RaisedCosineTransmitFilter( ...
                'OutputSamplesPerSymbol',a.ss,...
                'FilterSpanInSymbols',2);
            
            a.rxFilter = comm.RaisedCosineReceiveFilter(...
                'InputSamplesPerSymbol',a.ss,'DecimationFactor',a.ss,...
                'FilterSpanInSymbols',2);
           
            a.tx = sdrtx('Pluto', 'CenterFrequency', a.fc,...
                'BasebandSampleRate', a.rs, 'Gain', -5);

            a.rx = sdrrx('Pluto', 'CenterFrequency', a.fc,...
                'BasebandSampleRate', a.rs, 'GainSource', ...
                'Manual', 'Gain', 40, 'SamplesPerFrame',...
                a.fs, 'OutputDataType', 'single');
            % Increase frequency offset and phase offset to degrade signal
            a.pfo = comm.PhaseFrequencyOffset('PhaseOffset', 0.5,...
                'FrequencyOffset', 1000, 'SampleRate',a.rs);
            % Decrease EbNo to degrade signal
            a.channel=comm.AWGNChannel('SamplesPerSymbol',a.ss,'EbNo',100);
            
            a.syntonize = comm.CoarseFrequencyCompensator(...
                'SampleRate',a.rb, 'FrequencyResolution',1);
            a.synchronize = comm.CarrierSynchronizer( ...
                'SamplesPerSymbol',1);
            a.preamble_detector = comm.PreambleDetector(a.preamble,...
                'Threshold',3,'Detections','All');
      end
       
      function signal_in = encode(a, message)
          % encodes the message into a vector using ASCII in base a.QAM
          m = dec2base(message, a.QAM, a.ls);
          m = reshape(m', numel(m), []);
          signal_dec = base2dec(m, a.QAM);
          
          % applies QAM mapping
          QAM_signal = qammod(signal_dec, a.QAM);

          % inerpolation and optimal filter for ISI
          signal_in = [zeros(a.guard,1); a.preamble; QAM_signal;...
              a.preamble];          
      end
      
      function signal_out = propagate(a, signal_in)
          
          %transmits signal
          signal_tx = a.txFilter(signal_in);
          
          a.tx.transmitRepeat(signal_tx);
          
          % receives signal
          signal_out = a.rxFilter(a.rx());
      end
      
      function signal_out = simulate(a, signal_in)
          
          % transmitted signal
          signal_tx = a.txFilter([signal_in; zeros(a.guard,1)]);
%           scatterplot(signal_tx)
          
          % received signal
          signal_out = a.rxFilter(a.channel(a.pfo(signal_tx)));
%           scatterplot(signal_out)

          % signal_out = awgn(signal_in,18,'measured');
      end
      
      function [signal, message_out] = decode(a, signal_out)
          
          % synchronization of the signal
          signal_synt = a.syntonize(signal_out);
          signal_sync = a.synchronize(signal_synt);
%           figure(1)
%           scatterplot(signal_sync)
%           figure(2)
          plot(10*log10(abs(signal_sync)))
          % locating the preamble
          [~, correlation] = a.preamble_detector(signal_sync);
          
          [~, indices] = maxk(correlation, 2);
          data_end = max(indices) - length(a.preamble);
          data_start = min(indices) + 1;
          num_char = int32((data_end - data_start + 1)/a.ls);
          data_end = num_char*a.ls + data_start - 1;
          preamble_start = data_start - length(a.preamble);
          
%           phase correction 2.0
          preamble_out = signal_sync(preamble_start:data_start-1);
          phase_offset = round(mean(exp(1i*(angle(a.preamble) - ...
              angle(preamble_out)))));
          signal =signal_sync(data_start:data_end).*phase_offset;
%           signal =signal_sync(data_start:data_end);
%           scatterplot(signal_out(data_start:data_end

          plot(10*log10(abs(signal_sync)))     
          
          z = dec2base(qamdemod(signal,a.QAM), a.QAM);
          z = reshape(z, a.ls, [])';
          message_out = char(base2dec(z,a.QAM))';
      end
          
          
      
      function release(a)
%           release(a.preamble())
          release(a.tx)
          release(a.rx)
%           Release(a.txFilter)
%           release(a.rxFilter)
          release(a.pfo)
          release(a.channel)
          release(a.syntonize)
          release(a.synchronize)
          release(a.preamble_detector)
          
      end         
   end
end