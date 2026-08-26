classdef Port < handle
  properties
    Name
    Owner
    Direction       % "input" or "output"
    MessageType
    Required = true
    % Sync policies: "exactTime", "nearest", "latest", "holdLast", "sequence", "key"
    SyncPolicy = "exactTime"
    Tolerance = 0.001
    SyncKey = []    % Function handle to extract a custom key (e.g., @(msg) msg.key)
    Buffer = {}
    LastMessage = []
  end

  methods
    function obj = Port(owner, name, direction, varargin)
      obj.Owner = owner;
      obj.Name = name;
      obj.Direction = direction;
      
      for k = 1:2:numel(varargin)
        obj.(varargin{k}) = varargin{k+1};
      end

      obj.validate();
    end

    function receive(obj, msg)
      if ~strcmp(obj.Direction, "input")
        error("Port '%s' is not an input port.", obj.Name);
      end
      obj.Buffer{end+1} = msg;
    end

    function msg = getBuffer(obj)
      if isempty(obj.Buffer)
        msg = {};
      else
        msg = obj.Buffer;
      end
    end

    function clear(obj)
      obj.Buffer = {};
      obj.LastMessage = [];
    end

    function validate(obj)

      switch string(obj.SyncPolicy)

        case "key"
          if isempty(obj.SyncKey) || ~isa(obj.SyncKey, 'function_handle')
            error( ...
              "Port '%s' uses 'key' synchronization but SyncKey " + ...
              "is missing or is not a function handle.", ...
              obj.Name);
          end

        case {"exactTime", "nearest", "latest", "holdLast", "sequence"}
          % No additional validation required.

        otherwise
          error( ...
            "Unknown synchronization policy '%s' on port '%s'.", ...
            obj.SyncPolicy, obj.Name);
      end
    end
  end
end