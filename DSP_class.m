classdef DSP_class
   properties
       
       % default values
       fc = 868e6;       % carrier frequency in Hz
       rb = 50e3;        % symbols (bits) per second
       ss = 8;           % samples per symbol
       QAM = 4;          % size of QAM constellation
       plen = 26;        % preamble length
       delay = 50;       % approximate delay of the transmitter
       fs                % samples per frame
       rs                % samples per second
       ls                %symbols per letter
       mlen              % message length
       
       
       % dependable variables and System Objects
       preamble
       txFIR
       rxFIR
       tx
       rx
       pfo
       channel
       syntonize
       synchronize
       preamble_detector
       slope_detector
       
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
               a.preamble = (log2(a.QAM)-1)*complex(a.preamble(),...
                   fliplr(a.preamble()')');
            else
               a.preamble = a.preamble();
            end
           
            % samples per frame
            a.fs = (2*a.plen + 2*a.mlen )*a.ss;
            
            a.txFIR = dsp.FIRInterpolator('InterpolationFactor', a.ss,...
                'Numerator', firpm(100,[0 1/a.ss 2/a.ss 1],...
                [1 1 0 0], [1 1]));
            a.rxFIR = dsp.FIRDecimator('DecimationFactor', a.ss,...
                'Numerator', firpm(100,[0 1/a.ss  2/a.ss 1],...
                [1 1 0 0], [1 1]));
           
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
            
            a.preamble_detector = comm.PreambleDetector(a.preamble,...
                'Threshold',3,'Detections','All');
            
            a.slope_detector = comm.PreambleDetector(repelem([-1;1],...
                a.ss), 'Threshold',10,'Detections','First');
            
           % simulation Ojects
           % Increase frequency offset and phase offset to degrade signal
           a.pfo = comm.PhaseFrequencyOffset('PhaseOffset', 237,...
               'FrequencyOffset', 223, 'SampleRate',a.rs);
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

          signal_tx = a.txFIR([a.preamble; signal_in; a.preamble]);
          signal_tx = 2*signal_tx(51 + (a.plen/2)*a.ss : ...
              50 + end - (a.plen/2)*a.ss);
            
          % transmits signal
          a.tx.transmitRepeat(signal_tx);
          
          % receives signal
          signal_tx = a.rx();
          signal_out = signal_tx/max(abs(signal_tx));
          
      end
      
      function signal_out = simulate(a, signal_in)
          
          % transmitted signal
          signal_tx = a.txFilter([a.preamble(a.plen/2-1:end);...
              signal_in; a.preamble(1:a.plen/2)]);
          
          % received signal
          signal_tx = a.rxFilter(a.channel(a.pfo(signal_tx)));
          signal_out = signal_tx/max(abs(signal_tx));
          
      end
      
      function [preamble_cond, signal_cond] = conditioning(a, signal_out)
          
          signal_synt = a.syntonize(signal_out);
          signal_sync = a.synchronize(signal_synt);

          [~, slope] = a.slope_detector(imag(signal_sync));
          [~, index] = max(slope);
          align = mod(index - a.ss/2, a.ss);
          signal_align = signal_out(1+align:end+align-a.ss);

          signal_filtered = 2*a.rxFIR(signal_align);
            
          % locating the preamble
          [~, correlation] = a.preamble_detector(signal_filtered);
          [~, index] = maxk(correlation, 2);
          data_end = index(1) + a.mlen;
          if data_end <= length(signal_filtered)
              data_start = index(1) + 1;
          else
              data_end = index(2) + a.mlen;
              data_start = index(2) + 1;
          end
          preamble_start = data_start - a.plen;
          
          % phase correction 2.0 (corrects only by n*pi/4 where n is int)
          preamble_filtered = signal_filtered(preamble_start:data_start-1);

          phase_offset = (mean(exp(1i*(angle(a.preamble(...
              end-a.plen+1:end)) - angle(preamble_filtered)))));
          signal_cond =signal_filtered(data_start:data_end).*phase_offset;
          preamble_cond = preamble_filtered.*phase_offset;
         
      end 
      
      function message_out = decode(a, signal)
          
          z = dec2base(qamdemod(signal,a.QAM), a.QAM);
          z = reshape(z, a.ls, [])';
          message_out = char(base2dec(z,a.QAM))';
          
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