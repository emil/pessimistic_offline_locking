# -*- coding: utf-8 -*-

class LogCapture

  # The result of capturing:
  attr_reader :captured

  LOG_FILE = File.expand_path('../../../log/debug.log',__FILE__) unless defined?(LOG_FILE)

  module Assertions

    # checks the test_xxx.log files, NOT the database
    # record the number of lines in the log file at before and after
    # the action being performed, then use tail to grab the last n lines
    # logged
    def assert_logged(targets, log_level = nil, match = true, &block)
      start_lines = '0' unless File.exists?(LOG_FILE)

      regexes = [] << targets # in case we get a non-array (single string/regex)
      regexes.flatten!
      regexes.map! {|regex| regex.is_a?(String) ? /#{Regexp.escape(regex)}/m : regex}

      log_str = LOG4R_LEVELS[log_level] || 'All'

      start_lines ||= `wc -l #{LOG_FILE}`

      yield block

      end_lines = `wc -l #{LOG_FILE}`

      # "  206777 /Users/donncha/development/tasks/fd-prov/log/test_20130108.log\n"
      assert !start_lines.nil? && !end_lines.nil?

      start_lines = start_lines.strip.split(/\s/)[0].to_i
      end_lines = end_lines.strip.split(/\s/)[0].to_i

      captured = `tail -n #{end_lines - start_lines} #{LOG_FILE}`.split(/\n/)

      # Lines start with the following format
      # "2013-01-08 PST 16:21:29 DEBUG: "
      unless log_level.nil?
        expected_log_str = log_str + ":"
        captured = captured.select {|x| x[0..40].split(/\s/)[3] == expected_log_str}
      end

      regexes.each do |regex|
        if match
          assert !captured.blank?, "should have logged some message at given level #{log_str}"
          assert captured.detect {|msg| msg =~ regex }, "A log entry should have matched the regular expression #{regex} at the given level: #{log_str} in file #{LOG_FILE}}"
        else
          return if captured.blank? # trivial case
          assert captured.all? {|msg| !(msg =~ regex) }, "No log entry should have matched the regular expression #{regex} at the given level: #{log_str}. in file #{LOG_FILE}}"
        end
      end

      return captured
    end

    # just the opposite of assert_logged
    def assert_not_logged(targets, log_level = nil, &block)
      assert_logged(targets, log_level, false) { yield block }
    end

    LOG4R_LEVELS = { 1 => "DEBUG" , 2 => "INFO", 3 => "WARN", 4 => "ERROR" }.freeze unless defined?(LOG4R_LEVELS)

  end
end
