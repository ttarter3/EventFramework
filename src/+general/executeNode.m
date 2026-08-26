function result = executeNode(execution)
% Rehydrate the node on the worker thread
node = feval(execution.nodeClass, execution.nodeName, execution.config);
node.State = execution.state;

% Execute algorithm
outputs = node.process(execution.inputs, execution.context);

% Package result
result = struct();
result.nodeName = execution.nodeName;
result.outputs = outputs;
result.state = node.State;
result.context = execution.context;
end