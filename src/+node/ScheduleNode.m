classdef ScheduleNode < general.Node
  methods
    function obj = ScheduleNode(name, config)
      obj@general.Node(name, config);

      % Output: The generated schedule
      obj.addOutputPort("cpi_schedule", msg.Schedule());
    end

    function initialize(obj, context)
      obj.State = struct();
      obj.State.cpi_id = 0;

      % Schedule the very first publication at t = 0
      context.simulation.Scheduler.schedule(context.time, ...
        @() obj.publishSchedule(context.simulation), "Publish Schedule");
    end

    function publishSchedule(obj, simulation)
      t = simulation.Scheduler.CurrentTime;
      obj.State.cpi_id = obj.State.cpi_id + 1;

      % Create the strongly-typed payload
      sched = msg.Schedule();
      sched.cpi_id = obj.State.cpi_id;
      sched.num_pris = obj.Config.num_pris;
      sched.num_samples = obj.Config.num_samples;

      fprintf('[t=%.3f] %s generating Schedule for CPI %d (%dx%d matrix).\n', ...
        t, obj.Name, sched.cpi_id, sched.num_pris, sched.num_samples);

      % Wrap and publish manually
      m = struct();
      m.type = string(class(sched));
      m.source = obj.Name;
      m.sequence = obj.State.cpi_id;
      m.time = struct('measurement', t, 'generated', t, 'arrival', []);
      m.data = sched;

      simulation.Bus.publish(obj, "cpi_schedule", m);

      % Schedule the next CPI burst
      nextTime = t + obj.Config.cpi_interval;
      if nextTime <= simulation.StopTime
        simulation.Scheduler.schedule(nextTime, ...
          @() obj.publishSchedule(simulation), "Publish Schedule");
      end
    end
  end
end