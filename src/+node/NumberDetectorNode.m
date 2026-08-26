classdef NumberDetectorNode < general.Node
  methods
    function obj = NumberDetectorNode(name, config)
      obj@general.Node(name, config);

      % 1. Tell the Executor to farm this out to a background thread
      obj.ExecutionMode = "parallel";

      % 2. Define how much VIRTUAL time this algorithm takes.
      % (e.g., this takes 200 milliseconds of simulation time to run)
      obj.ProcessingLatency = 0.200; 

      % Input: The stitched FullImage
      obj.addInputPort("image_in", msg.FullImage(), "exactTime", 0, true);

      % Output: The detected number
      obj.addOutputPort("detection", msg.NumberDetection());
    end

    function initialize(obj, context) %#ok<INUSD> 
      % Parallel nodes should not mutate state, but we must initialize the struct
      obj.State = struct();
    end

    function outputs = process(obj, inputs, context)
      img = inputs.image_in.data;
      pixels = img.pixels;

      % --- SIMULATE HEAVY CPU WORK ---
      % Pause the background thread for 0.5 real wall-clock seconds.
      % The main simulation loop will NOT freeze!
      pause(0.5); 

      % --- SIMULATE IMAGE CLASSIFICATION ---
      % We grab a pixel inside the 255-intensity border (e.g., row 2, col 2)
      % and reverse the math (intensity = CPI_ID * 10) to detect the number.
      sampled_intensity = pixels(2, 2); 
      detected_num = round(sampled_intensity / 10);

      fprintf('\t[Worker Thread] Detected number %d in CPI %d at Sim Time t=%.3f!\n', ...
        detected_num, img.cpi_id, context.time);

      % Package the output
      result = msg.NumberDetection();
      result.cpi_id = img.cpi_id;
      result.detected_number = detected_num;
      result.confidence = 0.99; % Simulated high confidence

      outputs.detection = result;
    end
  end
end