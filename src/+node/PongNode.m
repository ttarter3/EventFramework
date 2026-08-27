classdef PongNode < general.Node
  properties
    latency_array
  end

  methods
    function obj = PongNode(name, config)
      obj@general.Node(name, config);
      obj.ExecutionMode = "serial";

      % Expect a struct and trigger whenever a new ping arrives
      obj.addInputPort("ping_in", "struct", "latest", 0, true);

      obj.latency_array = [];
    end

    function initialize(obj, context)
      obj.State = struct();
    end

    function outputs = process(obj, inputs, context)
      % Calculate real-world elapsed time since creation
      latency = toc(inputs.ping_in.data.timestamp);
  
      obj.latency_array(end + 1) = latency;

      fprintf('Framework Overhead at Sim Time t=%.3f: %.6f seconds\n', context.time, mean(obj.latency_array));
      outputs = [];
    end
  end
end