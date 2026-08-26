classdef Msg < handle
  properties
    Timestamp
    Source
    SequenceID
  end

  methods
    function obj = Msg(varargin)
      % Optional constructor to quickly populate metadata fields
      if nargin > 0 && isstruct(varargin{1})
        opts = varargin{1};
        if isfield(opts, 'Timestamp'), obj.Timestamp = opts.Timestamp; end
        if isfield(opts, 'Source'), obj.Source = opts.Source; end
        if isfield(opts, 'SequenceID'), obj.SequenceID = opts.SequenceID; end
      end
    end
  end
end