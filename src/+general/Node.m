classdef Node < handle
  properties
    Name
    Config
    State
    InputPorts
    OutputPorts
    Initialized = false
    ExecutionMode = "serial"
    ProcessingLatency = 0
  end

  methods
    function obj = Node(name, config)
      if nargin < 2
        config = struct();
      end
      obj.Name = name;
      obj.Config = config;
      obj.InputPorts = containers.Map('KeyType', 'char', 'ValueType', 'any');
      obj.OutputPorts = containers.Map('KeyType', 'char', 'ValueType', 'any');
      obj.State = struct();
    end

    function addInputPort(obj, name, messageTypeOrObject, syncPolicy, tolerance, required, syncKey)
      if nargin <= 4, syncPolicy = "exactTime"; end
      if nargin <= 5, tolerance = 0.001; end
      if nargin <= 6, required = true; end
      if nargin < 7, syncKey = []; end

      % Auto-detect the type
      if ischar(messageTypeOrObject) || isstring(messageTypeOrObject)
        msgType = string(messageTypeOrObject);
      else
        msgType = string(class(messageTypeOrObject));
      end

      port = general.Port(obj, name, "input", ...
        'MessageType', msgType, ...
        'SyncPolicy', string(syncPolicy), ...
        'Tolerance', tolerance, ...
        'Required', required, ...
        'SyncKey', syncKey);

      obj.InputPorts(char(name)) = port;
    end

    function addOutputPort(obj, name, messageTypeOrObject)
      % Auto-detect the type
      if ischar(messageTypeOrObject) || isstring(messageTypeOrObject)
        msgType = string(messageTypeOrObject);
      else
        msgType = string(class(messageTypeOrObject));
      end

      port = general.Port(obj, name, "output", 'MessageType', msgType);
      obj.OutputPorts(char(name)) = port;
    end

    function port = getInputPort(obj, name)
      port = obj.InputPorts(char(name));
    end

    function port = getOutputPort(obj, name)
      port = obj.OutputPorts(char(name));
    end

    function tf = isParallelSafe(obj)
      tf = obj.ExecutionMode == "parallel";
    end

    function configure(obj, config)
      obj.Config = config;
    end

    function initialize(obj, context) %#ok<INUSD>
      obj.State = struct();
      obj.Initialized = true;
    end

    function reset(obj)
      obj.State = struct();
      obj.Initialized = false;
      keys = obj.InputPorts.keys;
      for k = 1:numel(keys)
        obj.InputPorts(keys{k}).clear();
      end
    end

    function outputs = process(obj, inputs, context) %#ok<INUSD>
      error("Node '%s' must override process().", obj.Name);
    end
  end
end