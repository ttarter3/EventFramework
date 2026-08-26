classdef MessageBus < handle
  properties
    Scheduler
    Connections = general.Connection.empty
    Simulation
  end

  methods
    function obj = MessageBus(scheduler)
      obj.Scheduler = scheduler;
    end

    function addConnection(obj, connection)
      obj.Connections(end+1) = connection;
    end

    function publish(obj, sourceNode, sourcePort, msg)
      for k = 1:numel(obj.Connections)
        connection = obj.Connections(k);
        if ~connection.Enabled || ~strcmp(connection.SourceNode.Name, sourceNode.Name) || ~strcmp(connection.SourcePort, sourcePort)
          continue;
        end
        if connection.shouldDrop(msg)
          continue;
        end

        latency = connection.getLatency(msg);
        arrivalTime = msg.time.generated + latency;

        deliveredMessage = msg;
        deliveredMessage.time.arrival = arrivalTime;

        obj.Scheduler.schedule(arrivalTime, ...
          @() obj.deliver(connection, deliveredMessage), ...
          sprintf("%s -> %s", sourceNode.Name, connection.DestinationNode.Name));
      end
    end

    function deliver(obj, connection, msg)
      port = connection.DestinationNode.getInputPort(connection.DestinationPort);
      port.receive(msg);
      obj.tryExecute(connection.DestinationNode);
    end

    function tryExecute(obj, node)
      [ready, inputs] = general.Synchronizer.synchronize(node);
      if ~ready
        return;
      end

      context = struct();
      context.time = obj.Scheduler.CurrentTime;
      context.dt = 0;
      context.simulation = obj.Simulation;

      % Delegate execution to the asynchronous Executor
      obj.Simulation.Executor.submit(node, inputs, context);
    end

    function publishOutputs(obj, node, outputs, context)
      portNames = node.OutputPorts.keys;
      for k = 1:numel(portNames)
        portName = portNames{k};
        if ~isfield(outputs, portName)
          continue;
        end

        outValue = outputs.(portName);

        msg = struct();
        msg.type = node.OutputPorts(portName).MessageType;
        msg.source = node.Name;
        msg.time = struct('measurement', context.time, 'generated', context.time, 'arrival', []);

        % Check if node provided a custom key wrapper
        if isstruct(outValue) && isfield(outValue, 'data') && isfield(outValue, 'key')
          msg.data = outValue.data;
          msg.key = outValue.key;
          msg.sequence = [];
        else
          msg.data = outValue;
          msg.key = [];
          

          msg.sequence = obj.Scheduler.NextSequence;
          obj.Scheduler.NextSequence = obj.Scheduler.NextSequence + 1;
        end

        obj.publish(node, portName, msg);
      end
    end
  end
end