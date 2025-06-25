require "../interfaces"
require "./text_report_generator"
require "./json_report_generator"
require "./html_report_generator"
require "./logger_report_generator"

module CQL::Performance::Reports
  # Factory for creating report generators (Factory Pattern)
  class ReportGeneratorFactory
    @@generators = {
      "text" => TextReportGenerator.new,
      "json" => JsonReportGenerator.new,
      "html" => HtmlReportGenerator.new,
      "logger" => LoggerReportGenerator.new
    }

    def self.create(format : String) : ReportGenerator
      generator = @@generators[format.downcase]?
      return generator if generator

      # Default to text if format not found
      @@generators["text"]
    end

    def self.register_generator(generator : ReportGenerator) : Void
      @@generators[generator.format] = generator
    end

    def self.available_formats : Array(String)
      @@generators.keys
    end
  end
end
