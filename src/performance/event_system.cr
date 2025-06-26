# Event System for Performance Monitoring
# Implements Observer Pattern for loose coupling

require "./interfaces"

module CQL::Performance
  # Implementation of EventPublisher using Observer Pattern
  class EventBus < EventPublisher
    Log = CQL.config.logger

    @listeners : Array(EventListener) = [] of EventListener
    @enabled : Bool = true

    def initialize(@enabled : Bool = true)
    end

    def publish(event : MonitoringEvent) : Void
      return unless @enabled

      Log.debug { "Publishing event: #{event.class}" }

      @listeners.each do |listener|
        begin
          listener.handle_event(event)
        rescue ex : Exception
          Log.error { "Error in event listener: #{ex.message}" }
        end
      end
    end

    def subscribe(listener : EventListener) : Void
      unless @listeners.includes?(listener)
        @listeners << listener
        Log.debug { "Subscribed listener: #{listener.class}" }
      end
    end

    def unsubscribe(listener : EventListener) : Void
      @listeners.delete(listener)
      Log.debug { "Unsubscribed listener: #{listener.class}" }
    end

    def clear_listeners : Void
      @listeners.clear
    end

    def listener_count : Int32
      @listeners.size
    end

    def enabled=(value : Bool)
      @enabled = value
    end

    def enabled? : Bool
      @enabled
    end
  end

  # Async event publisher for non-blocking event handling
  class AsyncEventBus < EventPublisher
    Log = ::Log.for(self)

    @listeners : Array(EventListener) = [] of EventListener
    @event_queue : Channel(MonitoringEvent) = Channel(MonitoringEvent).new(1000)
    @enabled : Bool = true
    @processing : Bool = false

    def initialize(@enabled : Bool = true)
      start_processing_fiber if @enabled
    end

    def publish(event : MonitoringEvent) : Void
      return unless @enabled

      begin
        @event_queue.send(event)
      rescue ex : Channel::ClosedError
        Log.warn { "Event queue is closed, cannot publish event" }
      end
    end

    def subscribe(listener : EventListener) : Void
      unless @listeners.includes?(listener)
        @listeners << listener
        Log.debug { "Subscribed listener: #{listener.class}" }
      end
    end

    def unsubscribe(listener : EventListener) : Void
      @listeners.delete(listener)
      Log.debug { "Unsubscribed listener: #{listener.class}" }
    end

    def close : Void
      @enabled = false
      @event_queue.close
    end

    private def start_processing_fiber
      @processing = true

      spawn do
        while @enabled
          begin
            event = @event_queue.receive
            process_event(event)
          rescue ex : Channel::ClosedError
            Log.debug { "Event processing stopped" }
            break
          rescue ex : Exception
            Log.error { "Error processing event: #{ex.message}" }
          end
        end
        @processing = false
      end
    end

    private def process_event(event : MonitoringEvent)
      @listeners.each do |listener|
        begin
          listener.handle_event(event)
        rescue ex : Exception
          Log.error { "Error in async event listener: #{ex.message}" }
        end
      end
    end
  end
end
