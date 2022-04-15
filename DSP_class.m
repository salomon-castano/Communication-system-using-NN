classdef DSP_class
   properties
       
       % default values
       fc = 868e6;       % carrier frequency in Hz
       rb = 50e3;        % symbols (bits) per second
       ss = 8;           % samples per symbol
       fco = 1;          % normalized cutoff frequency 
       QAM = 4;          % size of QAM constellation
       plen = 26;        % preamble length
       delay = 50;       % approximate delay of the transmitter
       fs                % samples per frame
       rs                % samples per second
       ls                % symbols per letter
       mlen              % message length
       flen              % FIR filters length
       preamble          % preamble
       
       % dependable variables and System Objects
       
       preamble_maker
       txFIR
       rxFIR
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
            
            a.flen = a.ss*8;        % FIR filters length
            
            a.preamble_maker = comm.BarkerCode('SamplesPerFrame',...
            a.plen, 'Length',13); 
           
            if a.QAM > 2
               a.preamble = (log2(a.QAM)-1)*complex(a.preamble_maker(),...
                   fliplr(a.preamble_maker()')');
            else
               a.preamble = a.preamble_maker();
            end
           
            % samples per frame
            a.fs = (2*a.plen + 2*a.mlen )*a.ss;
            
            a.txFIR = dsp.FIRInterpolator('InterpolationFactor', a.ss,...
                'Numerator', firpm(2*a.flen,[0 a.fco/a.ss 2*a.fco/a.ss,...
                1], [1 1 0 0], [1 1]));
            % sets the initial conditions for the FIR
            a.txFIR(a.preamble(end-ceil(a.flen/a.ss):end)); 
                        
            a.rxFIR = dsp.FIRDecimator('DecimationFactor', a.ss,...
                'Numerator', firpm(2*a.flen,[0 a.fco/a.ss 2*a.fco/a.ss,...
                1], [1 1 0 0], [1 1]));
            
            a.tx = sdrtx('Pluto', 'CenterFrequency', a.fc,...
                'BasebandSampleRate', a.rs, 'Gain', -50);

            a.rx = sdrrx('Pluto', 'CenterFrequency', a.fc,...
                'BasebandSampleRate', a.rs, 'GainSource', ...
                'Manual', 'Gain', 50, 'SamplesPerFrame',...
                a.fs, 'OutputDataType', 'single');
                                  
            a.syntonize = comm.CoarseFrequencyCompensator(...
                'SampleRate',a.rs, 'FrequencyResolution',1);
            
            a.synchronize = comm.CarrierSynchronizer( ...
                'SamplesPerSymbol',a.ss);
            
            a.preamble_detector = comm.PreambleDetector(circshift(...
                a.txFIR(a.preamble), - a.flen), 'Threshold',...
                3,'Detections','All');
                        
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

          signal_whole = [a.preamble(a.plen/2+1:end);...
              signal_in; a.preamble(1:a.plen/2)];
          signal_tx =  circshift(a.txFIR(signal_whole), -a.flen);
          
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
          
%           signal_synt = a.syntonize(signal_out);
%           signal_sync = a.synchronize(signal_synt);
          signal_sync = signal_out;
            
          % locating the preamble
          [~, correlation] = a.preamble_detector(signal_sync);
          [~, index] = maxk(correlation, 8);
                    
          align = mod(index(1), a.ss) + a.flen;
%           signal_align = signal_sync(align:end + align - a.ss);
          signal_align = circshift(signal_sync, - align);
          a.rxFIR(signal_align(end - ceil(a.flen/a.ss)*a.ss + 1:end)); 
          signal_filtered = 2*a.rxFIR(signal_align);
          
          index = int32((index - mod(index(1), a.ss))./a.ss);
          
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