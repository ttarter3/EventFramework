classdef Executor < handle
  properties
    Pool
    Mode = "threads"
    Simulation
  end

  methods
    function obj = Executor(mode)
      if nargin > 0
        obj.Mode = mode;
      end
      switch obj.Mode
        case "threads"
          obj.Pool = backgroundPool;
        case "processes"
          obj.Pool = parpool("Processes");
        otherwise
          error("Unknown execution mode.");
      end
    end

    function submit(obj, node, inputs, context)
      deliveryTime = context.time + node.ProcessingLatency;

      if node.isParallelSafe()
        % 1. PARALLEL NODES: Use stateless execution packet & ghost nodes.
        %
        % context.simulation is a live handle to the ENTIRE Simulation
        % object (Scheduler, MessageBus, Nodes map, Executor -- including
        % its BackgroundPool/parpool, and any node holding a figure, e.g.
        % ImageDisplayNode). None of that is serializable, and no parallel
        % node's process() currently needs it, so we strip it out of the
        % packet before it crosses the thread boundary instead of shipping
        % the whole simulation (and its figures/pool/futures) to the worker.
        parallelContext = context;
        parallelContext.simulation = [];

        execution = struct('nodeName', node.Name, 'nodeClass', class(node), ...
          'config', node.Config, 'state', node.State, 'inputs', inputs, 'context', parallelContext);

        future = parfeval(obj.Pool, @general.executeNode, 1, execution);

        obj.Simulation.Scheduler.schedule(deliveryTime, ...
          @() obj.commitFuture(node, future), ...
          sprintf("%s Completion", node.Name));
      else
        % 2. SERIAL NODES: Execute directly on the real object reference!
        % This allows self-scheduling callbacks (like emitLine) to modify the real state.
        outputs = node.process(inputs, context);

        res = struct();
        res.outputs = outputs;
        res.context = context;

        obj.Simulation.Scheduler.schedule(deliveryTime, ...
          @() obj.commitResult(node, res), ...
          sprintf("%s Completion", node.Name));
      end
    end

    function commitFuture(obj, node, future)
      res = fetchOutputs(future);
      obj.commitResult(node, res);
    end

    function commitResult(obj, node, result)
      % Serial nodes mutated their state directly in memory, and parallel nodes 
      % are strictly stateless, so we only need to publish the outputs here!
      obj.Simulation.Bus.publishOutputs(node, result.outputs, result.context);
    end
  end
end