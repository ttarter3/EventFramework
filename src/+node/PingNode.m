classdef PingNode < general.Node
  methods
    function obj = PingNode(name, config)
      obj@general.Node(name, config);
      obj.ExecutionMode = "serial";

      % Register output port for the struct payload
      obj.addOutputPort("ping_out", "struct");
    end

    function initialize(obj, context)
      obj.State = struct();
      % Schedule the very first ping publication at t = 0
      context.simulation.Scheduler.schedule(context.time, ...
        @() obj.sendPing(context.simulation), "Send Ping");
    end

    function sendPing(obj, simulation)
      t = simulation.Scheduler.CurrentTime;

      % Construct the message manually to inject the 'tic' timer
      msg = struct();
      msg.type = "struct";
      msg.source = obj.Name;
      msg.sequence = simulation.Scheduler.NextSequence;
      msg.time = struct('measurement', t, 'generated', t, 'arrival', []);
      msg.data = struct('timestamp', tic, 'payload', rand(100)); % Attach timer

      simulation.Scheduler.NextSequence = simulation.Scheduler.NextSequence + 1;
      simulation.Bus.publish(obj, "ping_out", msg);

      % Schedule the next ping for 0.1s later
      nextTime = t + 0.1;
      if nextTime <= simulation.StopTime
        simulation.Scheduler.schedule(nextTime, ...
          @() obj.sendPing(simulation), "Send Ping");
      end
    end

    function outputs = process(obj, inputs, context)
      % Required by abstract class, but unused for pure sources
      outputs = []; 
    end
  end
end