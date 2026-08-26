function runImageTest()
clear classes; % Clears stale OOP memory buffers
close all;
clc;

sim = general.Simulation();
sim.StartTime = 0;
sim.StopTime = 3; 

% --- 1. Configure Nodes (SCALED UP) ---
% Increased to 64x64 matrix
schedConfig = struct('num_pris', 64, 'num_samples', 64, 'cpi_interval', 1.0);
scheduler = node.ScheduleNode("MasterClock", schedConfig);

% Increased PRF to 256 Hz
genConfig = struct('PRF', 256);
generator = node.LineGeneratorNode("LineGenerator", genConfig);

stitcher = node.ImageStitcherNode("Stitcher",  struct());
displayNode = node.ImageDisplayNode("Display", struct());
detector = node.NumberDetectorNode("Detector", struct());

estConfig = struct();
estConfig.outputDir = 'simulation_output'; % Save folder
estimator = node.EstimationNode("NumberEstimator", estConfig);

% --- 2. Add Nodes to Graph ---
sim.addNode(scheduler);
sim.addNode(generator);
sim.addNode(stitcher);
sim.addNode(displayNode); 
sim.addNode(detector); 
sim.addNode(estimator);

% --- 3. Wire the Connections ---
sim.connect("MasterClock", "cpi_schedule", "LineGenerator", "cpi_schedule", 'Latency', 0.001);
sim.connect("MasterClock", "cpi_schedule", "Stitcher", "cpi_schedule", 'Latency', 0.001);
sim.connect("LineGenerator", "image_line", "Stitcher", "image_line", 'Latency', 0.002);
sim.connect("Stitcher", "full_image", "Display", "full_image", 'Latency', 0.005);
sim.connect("Stitcher", "full_image", "Detector", "image_in", 'Latency', 0.005);
sim.connect("Stitcher", "full_image", "NumberEstimator", "stitched_image", 'Latency', 0.010);

sim.visualize()

% --- 4. Run ---
disp("Starting Scaled Image Stitching Simulation...");
%% 
%% 
sim.run(20);
disp("Simulation Complete.");
end