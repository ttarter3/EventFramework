function runBenchmark(numPingers, numPongers)
if nargin < 2
  numPingers = 3;
  numPongers = 3;
end

% Removed `clear classes;` so it does not delete the input variables!
clc;

% 1. Setup Framework Benchmark
sim = general.Simulation();
sim.StartTime = 0;
sim.StopTime = 10.0; % 10 simulated seconds

% --- Create and Add Pongers (Receivers) ---
pongList = strings(numPongers, 1);
for j = 1:numPongers
  pName = sprintf("Ponger%d", j);
  pongList(j) = pName;
  sim.addNode(node.PongNode(pName, struct()));
end

% --- Create Pingers (Transmitters) and Connect ---
for i = 1:numPingers
  txName = sprintf("Pinger%d", i);
  sim.addNode(node.PingNode(txName, struct()));

  % Connect this Pinger to EVERY Ponger (Broadcast Topology)
  for j = 1:numPongers
    sim.connect(txName, "ping_out", pongList(j), "ping_in", 'Latency', 0);
  end
end

disp("--- Starting Scaled Framework Benchmark ---");
sim.run();

% 2. Setup Direct Call Baseline
disp("--- Starting Direct Function Call Benchmark ---");
direct_latency = zeros(10, 1);
for i = 1:10
  t_start = tic;
  dummyPayload = struct('timestamp', t_start, 'payload', rand(100));
  direct_latency(i) = toc(dummyPayload.timestamp);
end

fprintf('Average Direct Call Overhead: %.6f seconds\n', mean(direct_latency));
end