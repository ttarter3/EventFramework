classdef EstimationNode < general.Node
  methods
    function obj = EstimationNode(name, config)
      obj@general.Node(name, config);
      obj.ExecutionMode = "parallel";
      obj.ProcessingLatency = 0.250;
      
      obj.addInputPort("stitched_image", msg.FullImage());
      obj.addOutputPort("estimation_result", "Estimation");
    end
    
    function initialize(obj, context) %#ok<INUSD>
      obj.State = struct();
      
      if ~isfield(obj.Config, 'outputDir')
        obj.Config.outputDir = 'simulation_output';
      end
      if ~exist(obj.Config.outputDir, 'dir')
        mkdir(obj.Config.outputDir);
      end
      
      % --- PRE-GENERATE TEMPLATES ON MAIN SERIAL THREAD ---
      % Thread workers cannot use figure(). We render the text into 
      % standard arrays here before the simulation begins!
      obj.State.templates = cell(10, 1);
      hiRows = 256; 
      hiCols = 256;
      
      for d = 0:9
        tempFig = figure('Visible', 'off');
        tempAx = axes('Parent', tempFig);
        axis(tempAx, [1 hiCols 1 hiRows]);
        set(tempAx, 'Visible', 'off');
        
        text(hiCols/2, hiRows/2, num2str(d), ...
            'FontSize', hiRows * 0.85, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Color', [1 1 1], ...
            'FontWeight', 'bold');
            
        tempFrame = getframe(tempAx);
        close(tempFig);
        
        % Store just the raw image matrix (double). 
        % Cell index 1 maps to digit 0, index 2 to digit 1, etc.
        obj.State.templates{d + 1} = double(im2gray(tempFrame.cdata));
      end
    end
    
    function outputs = process(obj, inputs, context)
      inputMatrix = inputs.stitched_image.data.pixels;
      sequenceID = inputs.stitched_image.sequence;
      
      normalizedInput = node.EstimationNode.localMat2Gray(double(inputMatrix));
      
      % --- PARALLEL-SAFE CLASSIFICATION ---
      estimatedNumber = obj.classifyDigit(normalizedInput);
      
      outputMatrix = node.EstimationNode.localBinarize(normalizedInput);
      
      % --- FILE SAVING LOGIC ---
      outDir = obj.Config.outputDir;
      baseName = sprintf('CPI_%03d', sequenceID);
      
      inFilename = fullfile(outDir, sprintf('%s_INPUT.png', baseName));
      imwrite(normalizedInput, inFilename);
      
      outFilename = fullfile(outDir, sprintf('%s_OUTPUT.png', baseName));
      imwrite(outputMatrix, outFilename);
      
      textFilename = fullfile(outDir, sprintf('%s_DECLARATION.txt', baseName));
      fid = fopen(textFilename, 'w');
      fprintf(fid, 'Simulation Time: %.3f\n', context.time);
      fprintf(fid, 'CPI Sequence ID: %d\n', sequenceID);
      fprintf(fid, 'Estimated Number: %d\n', estimatedNumber);
      fclose(fid);
      
      fprintf('\t[EstimationNode] CPI %d analyzed. Classified Number: %d. Artifacts saved to /%s\n', ...
        sequenceID, estimatedNumber, outDir);
      
      outputs.estimation_result = struct(...
        'cpiID', sequenceID, ...
        'estimatedNumber', estimatedNumber ...
        );
    end
    
    function bestDigit = classifyDigit(obj, img)
      [rows, cols] = size(img);
      bestDigit = 0;
      minError = inf;
      
      for d = 0:9
        % Retrieve the pre-rendered matrix from State
        hiResTemplate = obj.State.templates{d + 1};
        
        % imresize is purely mathematical and safe for background workers
        refTemplate = imresize(hiResTemplate, [rows cols], 'bilinear');
        refTemplate = node.EstimationNode.localMat2Gray(refTemplate);
        
        err = mean((img(:) - refTemplate(:)).^2);
        
        if err < minError
          minError = err;
          bestDigit = d;
        end
      end
    end
  end
  
  methods (Static)
    function g = localMat2Gray(A)
      A = double(A);
      lo = min(A(:));
      hi = max(A(:));
      if hi > lo
        g = (A - lo) / (hi - lo);
      else
        g = zeros(size(A));
      end
    end
    
    function bw = localBinarize(g)
      bw = g > mean(g(:));
    end
  end
end