classdef Connection < handle
  properties
    SourceNode
    SourcePort
    DestinationNode
    DestinationPort
    Latency = 0
    Enabled = true
    DropFunction = []
  end

  methods
    function obj = Connection(sourceNode, sourcePort, destinationNode, destinationPort, varargin)
      obj.SourceNode = sourceNode;
      obj.SourcePort = sourcePort;
      obj.DestinationNode = destinationNode;
      obj.DestinationPort = destinationPort;
      for k = 1:2:numel(varargin)
        obj.(varargin{k}) = varargin{k+1};
      end
    end

    function latency = getLatency(obj, msg)
      if isempty(obj.Latency)
        latency = 0;
      elseif isa(obj.Latency, 'function_handle')
        latency = obj.Latency(msg);
      else
        latency = obj.Latency;
      end
    end

    function drop = shouldDrop(obj, msg)
      if isempty(obj.DropFunction)
        drop = false;
      else
        drop = obj.DropFunction(msg);
      end
    end
  end
end