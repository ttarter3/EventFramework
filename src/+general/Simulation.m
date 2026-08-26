classdef Simulation < handle
  properties
    Scheduler
    Bus
    Executor
    Nodes
    StartTime = 0
    StopTime = 10
  end

  methods
    function obj = Simulation()
      % Instantiate Map internally so it doesn't leak between simulation runs
      obj.Nodes = containers.Map('KeyType', 'char', 'ValueType', 'any');

      obj.Scheduler = general.Scheduler();
      obj.Bus = general.MessageBus(obj.Scheduler);
      obj.Bus.Simulation = obj;


      % These are ordinary computation/file-I/O calls and should be fine on a thread-based pool, but if you ever get another "not supported on a thread-based worker" error pointing at one of them, the quickest fix is switching execution modes — general.Executor("processes") instead of "threads" in Simulation's constructor — since Executor already supports a parpool("Processes") path. Processes are heavier but have none of the thread-pool restrictions (graphics, certain toolbox functions, etc.).
      obj.Executor = general.Executor("threads");
      obj.Executor.Simulation = obj;
    end

    function addNode(obj, node)
      if isKey(obj.Nodes, node.Name)
        error("Node '%s' already exists.", node.Name);
      end
      obj.Nodes(node.Name) = node;
    end

    function node = getNode(obj, name)
      node = obj.Nodes(char(name));
    end

    function connect(obj, sourceNode, sourcePort, destinationNode, destinationPort, varargin)
      src = obj.getNode(sourceNode);
      dst = obj.getNode(destinationNode);

      outPort = src.getOutputPort(sourcePort);
      inPort = dst.getInputPort(destinationPort);

      % Strict connection validation
      if ~strcmp(outPort.MessageType, inPort.MessageType)
        error("Connection Refused: Type Mismatch!\nSource '%s.%s' outputs type ['%s'].\nDestination '%s.%s' expects type ['%s'].", ...
          src.Name, sourcePort, outPort.MessageType, ...
          dst.Name, destinationPort, inPort.MessageType);
      end

      connection = general.Connection(src, sourcePort, dst, destinationPort, varargin{:});
      obj.Bus.addConnection(connection);
    end

    function initialize(obj)
      context = struct();
      context.time = obj.StartTime;
      context.simulation = obj;

      names = obj.Nodes.keys;
      for k = 1:numel(names)
        node = obj.Nodes(names{k});
        node.initialize(context);
      end
    end

    function run(obj, stopTime)
      if nargin > 1
        obj.StopTime = stopTime;
      end
      obj.initialize();
      obj.Scheduler.CurrentTime = obj.StartTime;
      obj.Scheduler.run(obj.StopTime);
    end

    function reset(obj)
      names = obj.Nodes.keys;
      for k = 1:numel(names)
        obj.Nodes(names{k}).reset();
      end
      obj.Scheduler.clear();
    end

    function visualize(obj)
      if isempty(obj.Bus.Connections)
        disp("No connections to visualize.");
        return;
      end

      numConnections = numel(obj.Bus.Connections);
      sources = strings(1, numConnections);
      targets = strings(1, numConnections);
      edgeLabels = strings(1, numConnections);

      for k = 1:numConnections
        conn = obj.Bus.Connections(k);
        sources(k) = string(conn.SourceNode.Name);
        targets(k) = string(conn.DestinationNode.Name);
        edgeLabels(k) = sprintf('%s -> %s', conn.SourcePort, conn.DestinationPort);
      end

      G = digraph(sources, targets);

      figure('Name', 'Simulation Architecture', 'Color', 'w');
      p = plot(G, 'Layout', 'layered', 'Direction', 'down');

      p.EdgeLabel = edgeLabels;
      p.NodeColor = [0.0 0.447 0.741];
      p.MarkerSize = 10;
      p.NodeFontSize = 12;
      p.EdgeFontSize = 10;
      title('Radar PubSub Simulation Node Graph', 'FontSize', 14);

      set(gca, 'XTick', [], 'YTick', []);
    end
  end
end