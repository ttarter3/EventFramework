classdef ImageDisplayNode < general.Node
  methods
    function obj = ImageDisplayNode(name, config)
      obj@general.Node(name, config);
      obj.ExecutionMode = "serial";
      obj.addInputPort("full_image", msg.FullImage(), "exactTime", 0, true);
    end

    function initialize(obj, context) %#ok<INUSD> 
      obj.State = struct();
      obj.State.fig = figure('Name', sprintf('Live View: %s', obj.Name), ...
        'NumberTitle', 'off', 'Color', 'w');
      obj.State.ax = axes('Parent', obj.State.fig);
    end

    function outputs = process(obj, inputs, context)
      img = inputs.full_image.data;

      if ~isvalid(obj.State.fig)
        obj.State.fig = figure('Name', sprintf('Live View: %s', obj.Name), 'NumberTitle', 'off');
        obj.State.ax = axes('Parent', obj.State.fig);
      end

      imagesc(obj.State.ax, img.pixels);
      colormap(obj.State.ax, 'gray');

      title(obj.State.ax, sprintf('CPI ID: %d | Sim Time: %.3f s', img.cpi_id, context.time), ...
        'FontSize', 14);
      xlabel(obj.State.ax, 'Samples (Fast-Time)');
      ylabel(obj.State.ax, 'PRIs (Slow-Time)');

      drawnow;

      % Pause for 0.5 real-world seconds so the human eye can see the image
      pause(0.5);

      outputs = [];
    end
  end
end