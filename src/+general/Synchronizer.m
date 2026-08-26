classdef Synchronizer
  methods (Static)
    function [ready, inputs] = synchronize(node)
      ready = false;
      inputs = struct();
      portNames = node.InputPorts.keys;

      % A required port blocks synchronization unless it has a message
      % available -- either freshly buffered, or (for "latest"/"holdLast"
      % policies) cached from a previous delivery via LastMessage.
      for k = 1:numel(portNames)
        port = node.InputPorts(portNames{k});
        if port.Required && ~general.Synchronizer.hasAvailableMessage(port)
          return;
        end
      end

      referencePort = [];
      for k = 1:numel(portNames)
        port = node.InputPorts(portNames{k});
        if port.Required && ~isempty(port.Buffer)
          referencePort = port;
          break;
        end
      end

      if isempty(referencePort)
        return;
      end

      referenceMsg = referencePort.Buffer{1};
      referenceTime = referenceMsg.time.measurement;
      referenceSequence = referenceMsg.sequence;

      selected = containers.Map('KeyType', 'char', 'ValueType', 'any');

      for k = 1:numel(portNames)
        name = portNames{k};
        port = node.InputPorts(name);

        [found, msg] = general.Synchronizer.findMessage(port, referenceTime, referenceSequence, referenceMsg);

        if port.Required && ~found
          return;
        end
        if found
          selected(name) = msg;
        end
      end

      names = selected.keys;
      for k = 1:numel(names)
        name = names{k};
        inputs.(name) = selected(name);
      end

      for k = 1:numel(names)
        name = names{k};
        port = node.InputPorts(name);
        msg = selected(name);
        general.Synchronizer.consumeMessage(port, msg);
      end

      ready = true;
    end

    function tf = hasAvailableMessage(port)
      % True if the port currently has something usable to offer the
      % synchronizer: a message sitting in its buffer, or -- for ports
      % using the "latest"/"holdLast" policies -- a previously cached
      % LastMessage that remains valid even after the buffer drains.
      tf = ~isempty(port.Buffer) || ...
        (~isempty(port.LastMessage) && ...
         (port.SyncPolicy == "latest" || port.SyncPolicy == "holdLast"));
    end

    function [found, msg] = findMessage(port, referenceTime, referenceSequence, referenceMsg)
      found = false;
      msg = [];
      if isempty(port.Buffer)
        if ~isempty(port.LastMessage)
          if strcmp(port.SyncPolicy, "latest") || strcmp(port.SyncPolicy, "holdLast")
            found = true;
            msg = port.LastMessage;
          end
        end
        return;
      end

      switch string(port.SyncPolicy)
        case "exactTime"
          for k = 1:numel(port.Buffer)
            candidate = port.Buffer{k};
            dt = abs(candidate.time.measurement - referenceTime);
            if dt <= port.Tolerance
              found = true;
              msg = candidate;
              return;
            end
          end
        case "nearest"
          bestDistance = inf;
          bestMessage = [];
          for k = 1:numel(port.Buffer)
            candidate = port.Buffer{k};
            dt = abs(candidate.time.measurement - referenceTime);
            if dt < bestDistance
              bestDistance = dt;
              bestMessage = candidate;
            end
          end
          if bestDistance <= port.Tolerance
            found = true;
            msg = bestMessage;
          end
        case "sequence"
          for k = 1:numel(port.Buffer)
            candidate = port.Buffer{k};
            if candidate.sequence == referenceSequence
              found = true;
              msg = candidate;
              return;
            end
          end
        case "key"
          if isempty(port.SyncKey)
            error("Port '%s' uses 'key' sync but no SyncKey function was provided.", port.Name);
          end
          referenceID = port.SyncKey(referenceMsg);
          for k = 1:numel(port.Buffer)
            candidate = port.Buffer{k};
            candidateID = port.SyncKey(candidate);
            if isequal(candidateID, referenceID)
              found = true;
              msg = candidate;
              return;
            end
          end
        case "latest"
          found = true;
          msg = port.Buffer{end};
        case "holdLast"
          found = true;
          msg = port.Buffer{end};
        otherwise
          error("Unknown synchronization policy '%s'.", port.SyncPolicy);
      end
    end

    function consumeMessage(port, msg)
      if isempty(port.Buffer)
        return;
      end

      port.LastMessage = msg;
      idx = [];
      for k = 1:numel(port.Buffer)
        if isequal(port.Buffer{k}, msg)
          idx = k;
          break;
        end
      end

      if isempty(idx)
        return;
      end

      if strcmp(port.SyncPolicy, "latest") || strcmp(port.SyncPolicy, "holdLast")
        port.Buffer(1:idx) = [];
      else
        port.Buffer(idx) = [];
      end
    end
  end
end