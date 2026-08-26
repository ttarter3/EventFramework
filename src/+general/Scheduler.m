classdef Scheduler < handle
  properties
    CurrentTime = 0
    Events = struct('time', {}, 'sequence', {}, 'callback', {}, 'description', {})
    NextSequence = 1
  end

  methods
    function schedule(obj, time, callback, description)
      if nargin <= 3, description = ""; end

      event.time = time;
      event.sequence = obj.NextSequence;
      event.callback = callback;
      event.description = description;

      obj.NextSequence = obj.NextSequence + 1;
      obj.Events(end+1) = event;

      % --- UPGRADE: Sort using raw arrays instead of tables ---
      % This prevents MATLAB from silently corrupting function handles!
      times = [obj.Events.time]';
      seqs = [obj.Events.sequence]';
      [~, sortIdx] = sortrows([times, seqs]);
      obj.Events = obj.Events(sortIdx);
    end

    function tf = isEmpty(obj)
      tf = isempty(obj.Events);
    end

    function event = pop(obj)
      if isempty(obj.Events)
        error("Scheduler is empty.");
      end
      event = obj.Events(1);
      obj.Events(1) = [];
      obj.CurrentTime = event.time;
    end

    function run(obj, stopTime)
      while ~obj.isEmpty()
        if obj.Events(1).time > stopTime
          break;
        end
        event = obj.pop();
        event.callback(); % Execute the event!
      end
      obj.CurrentTime = stopTime;
    end

    function clear(obj)
      obj.Events = struct('time', {}, 'sequence', {}, 'callback', {}, 'description', {});
      obj.NextSequence = 1;
      obj.CurrentTime = 0;
    end
  end
end