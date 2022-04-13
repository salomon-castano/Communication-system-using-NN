classdef DSP_class
   properties
       
       % default values
       fc = 900e6;       % carrier frequency in Hz
       rb = 60e3;        % symbols (bits) per second
       ss = 5;           % samples per symbol
       QAM = 4;          % size of QAM constellation
       plen = 26;        % preamble length
       delay = 500;      % approximate delay of the transmitter
       fs                % samples per frame
       rs                % samples per second
       ls                %symbols per letter
       mlen               % message length
       
       
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
      function a = setup(a, message) 
            % dependable var and System Objects initicalization
                        
            a.rs = a.ss*a.rb;   % samples per second
            
            a.ls = int32(8/log2(a.QAM)); %symbols per letter
            
            a.mlen = length(message)*a.ls; % message length in QAM symbols
          
            a.preamble = comm.BarkerCode('SamplesPerFrame', a.plen,...
               'Length',13); 
           
           if a.QAM > 2
               a.preamble = complex(a.preamble(),fliplr(a.preamble()));
           else
               a.preamble = a.preamble();
           end
           
           % samples per frame
           a.fs = 2*(length(a.preamble) + a.mlen - 1)*a.ss; 
           
            a.txFilter = comm.RaisedCosineTransmitFilter( ...
                'OutputSamplesPerSymbol',a.ss,...
                'FilterSpanInSymbols',1);
            
            a.rxFilter = comm.RaisedCosineReceiveFilter(...
                'InputSamplesPerSymbol',a.ss,'DecimationFactor',a.ss,...
                'FilterSpanInSymbols',1);
           
            a.tx = sdrtx('Pluto', 'CenterFrequency', a.fc,...
                'BasebandSampleRate', a.rs, 'Gain', -13);

            a.rx = sdrrx('Pluto', 'CenterFrequency', a.fc,...
                'BasebandSampleRate', a.rs, 'GainSource', ...
                'Manual', 'Gain', 40, 'SamplesPerFrame',...
                a.fs, 'OutputDataType', 'single');
            % Increase frequency offset and phase offset to degrade signal
            a.pfo = comm.PhaseFrequencyOffset('PhaseOffset', 237,...
                'FrequencyOffset', 223, 'SampleRate',a.rs);
            % Decrease EbNo to degrade signal
            a.channel=comm.AWGNChannel('SamplesPerSymbol',a.ss,'EbNo',50);
            
            a.syntonize = comm.CoarseFrequencyCompensator(...
                'SampleRate',a.rs, 'FrequencyResolution',1);
            a.synchronize = comm.CarrierSynchronizer( ...
                'SamplesPerSymbol',a.ss);
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
          signal_in = [a.preamble; QAM_signal];          
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
          signal_tx = a.txFilter([signal_in; zeros(a.delay,1)]);
%           scatterplot(signal_tx)
          
          % received signal
          signal_out = a.rxFilter(a.channel(a.pfo(signal_tx)));
%           scatterplot(signal_out)

%           signal_out = awgn(signal_in,18,'measured');
            
%           signal_out =signal_in;
      end
      
      function [preamble_cond, signal_cond] = conditioning(a, signal_out)
          
          % synchronization of the signal
          signal_sync = a.syntonize(signal_out);
          signal_sync = a.synchronize(signal_sync);
          
          % locating the preamble
          [~, correlation] = a.preamble_detector(signal_sync);
          [~, index] = maxk(correlation, 2);
          data_end = index(1) + a.mlen;
          if data_end < length(signal_sync)
              data_start = index(1) + 1;
          else
              data_end = index(2) + a.mlen;
              data_start = index(2) + 1;
          end
          preamble_start = data_start - a.plen;
          
%         phase correction 2.0 (corrects only by n*pi/4 where n is int)
          preamble_sync = signal_sync(preamble_start:data_start-1);

          phase_offset = (mean(exp(1i*(angle(a.preamble(...
              end-a.plen+1:end)) - angle(preamble_sync)))));
          signal_cond =signal_sync(data_start:data_end).*phase_offset;
          preamble_cond = preamble_sync.*phase_offset;

%           signal_cond =signal_sync(data_start:data_end);
%           preamble_cond = preamble_sync;
      end 
      
      function message_out = decode(a, signal)
          
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