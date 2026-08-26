classdef ImageStitcherNode < general.Node
  methods
    function obj = ImageStitcherNode(name, config)
      obj@general.Node(name, config);
      obj.ExecutionMode = "serial";

      % Define explicit key extractors for each message type payload
      lineKeyFunc = @(msg) msg.data.cpi_id;
      schedKeyFunc = @(msg) msg.data.cpi_id;

      % Pass the syncKey function handle directly as the 7th argument to each port
      % addInputPort(name, messageType, syncPolicy, tolerance, required, syncKey)
      obj.addInputPort("image_line", msg.ImageLine(), "key", 0, true, lineKeyFunc);
      obj.addInputPort("cpi_schedule", msg.Schedule(), "holdLast", 0, true);

      obj.addOutputPort("full_image", msg.FullImage());
    end

    function initialize(obj, context) %#ok<INUSD>
      obj.State = struct();
      obj.State.buffer = containers.Map('KeyType', 'double', 'ValueType', 'any');
    end

    function outputs = process(obj, inputs, context)
      sched = inputs.cpi_schedule.data;
      line = inputs.image_line.data;

      obj.State.buffer(line.line_index) = line.pixels;

      if mod(obj.State.buffer.Count, 16) == 0 || obj.State.buffer.Count == sched.num_pris
        fprintf('\t\t[Stitcher] Received line %d/%d for CPI %d.\n', ...
          obj.State.buffer.Count, sched.num_pris, sched.cpi_id);
      end

      if obj.State.buffer.Count == sched.num_pris
        fprintf('--> [t=%.3f] %s successfully stitched 64x64 Full Image for CPI %d!\n', ...
          context.time, obj.Name, sched.cpi_id);

        fullMatrix = zeros(sched.num_pris, sched.num_samples);
        for i = 1:sched.num_pris
          fullMatrix(i, :) = obj.State.buffer(i);
        end

        full = msg.FullImage();
        full.cpi_id = sched.cpi_id;
        full.pixels = fullMatrix;

        outputs.full_image = full;
        obj.State.buffer = containers.Map('KeyType', 'double', 'ValueType', 'any');
      else
        outputs = [];
      end
    end
  end
end