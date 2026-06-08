require "mutex"

module CQL
  module Compat
    {% if compare_versions(Crystal::VERSION, "1.20.0") >= 0 %}
      alias Mutex = ::Sync::Mutex
    {% else %}
      alias Mutex = ::Mutex
    {% end %}
  end
end
