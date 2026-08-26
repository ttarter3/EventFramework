classdef LineGeneratorNode < general.Node
  methods
    function obj = LineGeneratorNode(name, config)
      obj@general.Node(name, config);
      obj.ExecutionMode = "serial";
      obj.addInputPort("cpi_schedule", msg.Schedule(), "exactTime", 0, true);
      obj.addOutputPort("image_line", msg.ImageLine());
    end

    function initialize(obj, context) %#ok<INUSD>
      obj.State = struct();
      obj.State.isGenerating = false;
      obj.State.current_line = 0;
      obj.State.schedule = [];
      obj.State.image = [];
    end

    function outputs = process(obj, inputs, context)
      sched = inputs.cpi_schedule.data;
      if obj.State.isGenerating
        warning("LineGenerator is busy, ignoring new schedule!");
        outputs = []; return;
      end

      fprintf('\t[LineGenerator] Received CPI %d Schedule. Preparing to emit lines...\n', sched.cpi_id);

      obj.State.isGenerating = true;
      obj.State.current_line = 1;
      obj.State.schedule = sched;

      % --- DRAW A REAL NUMBER IMAGE ---
      % Create a blank canvas matching the requested matrix size (e.g., 64x64)
      rows = sched.num_pris;
      cols = sched.num_samples;
      canvas = zeros(rows, cols);

      % Determine which number to draw based on the CPI ID (cycles 0-9)
      targetNum = mod(sched.cpi_id, 10);

      % Use MATLAB's text rendering to draw the number onto the matrix canvas
      % We scale it to fit nicely within the grid dimensions
      fig = figure('Visible', 'off');
      ax = axes('Parent', fig);
      axis(ax, [1 cols 1 rows]);
      set(ax, 'Visible', 'off');
      text(cols/2, rows/2, num2str(targetNum), ...
        'FontSize', min(rows, cols)*5, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'Color', [1 1 1], ...
        'FontWeight', 'bold');

      % Capture the figure axes as a clean 2D binary image matrix
      frame = getframe(ax);
      close(fig);

      numImg = im2gray(imresize(frame.cdata, [rows cols]));

      % Store the generated number image in state
      obj.State.image = double(numImg);

      % Schedule the first line
      context.simulation.Scheduler.schedule(context.time, ...
        @() obj.emitLine(context.simulation), "Emit Image Line");

      outputs = [];
    end

    function emitLine(obj, simulation)
      if ~obj.State.isGenerating, return; end

      t = simulation.Scheduler.CurrentTime;
      idx = obj.State.current_line;
      sched = obj.State.schedule;

      lineData = msg.ImageLine();
      lineData.cpi_id = sched.cpi_id;
      lineData.line_index = idx;
      lineData.pixels = obj.State.image(idx, :);

      m = struct();
      m.type = string(class(lineData));
      m.source = obj.Name;
      m.sequence = idx;
      m.time = struct('measurement', t, 'generated', t, 'arrival', []);
      m.data = lineData;

      simulation.Bus.publish(obj, "image_line", m);

      obj.State.current_line = obj.State.current_line + 1;
      if obj.State.current_line <= sched.num_pris
        nextTime = t + (1 / obj.Config.PRF);
        if nextTime <= simulation.StopTime
          simulation.Scheduler.schedule(nextTime, ...
            @() obj.emitLine(simulation), "Emit Image Line");
        end
      else
        fprintf('\t[LineGenerator] Finished emitting all %d lines for CPI %d!\n', sched.num_pris, sched.cpi_id);
        obj.State.isGenerating = false;
      end
    end
  end
end