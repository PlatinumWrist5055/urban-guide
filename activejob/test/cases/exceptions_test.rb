# frozen_string_literal: true

require "helper"
require "jobs/retry_job"
require "models/person"

class ExceptionsTest < ActiveJob::TestCase
  setup do
    JobBuffer.clear
    skip if ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter)
  end

  test "successfully retry job throwing exception against defaults" do
    perform_enqueued_jobs do
      RetryJob.perform_later "DefaultsError", 5

      assert_equal [
        "Raised DefaultsError for the 1st time",
        "Raised DefaultsError for the 2nd time",
        "Raised DefaultsError for the 3rd time",
        "Raised DefaultsError for the 4th time",
        "Successfully completed job" ], JobBuffer.values
    end
  end

  test "successfully retry job throwing exception against higher limit" do
    perform_enqueued_jobs do
      RetryJob.perform_later "ShortWaitTenAttemptsError", 9
      assert_equal 9, JobBuffer.values.count
    end
  end

  test "keeps the same attempts counter when several exceptions are listed in the same declaration" do
    exceptions_to_raise = %w(FirstRetryableErrorOfTwo FirstRetryableErrorOfTwo FirstRetryableErrorOfTwo
                             SecondRetryableErrorOfTwo SecondRetryableErrorOfTwo)

    assert_raises SecondRetryableErrorOfTwo do
      perform_enqueued_jobs do
        ExceptionRetryJob.perform_later(exceptions_to_raise)
      end
    end
  end

  test "keeps a separate attempts counter for each individual declaration" do
    exceptions_to_raise = %w(FirstRetryableErrorOfTwo FirstRetryableErrorOfTwo FirstRetryableErrorOfTwo
                             DefaultsError DefaultsError)

    assert_nothing_raised do
      perform_enqueued_jobs do
        ExceptionRetryJob.perform_later(exceptions_to_raise)
      end
    end
  end

  test "failed retry job when exception kept occurring against defaults" do
    perform_enqueued_jobs do
      begin
        RetryJob.perform_later "DefaultsError", 6
        assert_equal "Raised DefaultsError for the 5th time", JobBuffer.last_value
      rescue DefaultsError
        pass
      end
    end
  end

  test "failed retry job when exception kept occurring against higher limit" do
    perform_enqueued_jobs do
      begin
        RetryJob.perform_later "ShortWaitTenAttemptsError", 11
        assert_equal "Raised ShortWaitTenAttemptsError for the 10th time", JobBuffer.last_value
      rescue ShortWaitTenAttemptsError
        pass
      end
    end
  end

  test "discard job" do
    perform_enqueued_jobs do
      RetryJob.perform_later "DiscardableError", 2
      assert_equal "Raised DiscardableError for the 1st time", JobBuffer.last_value
    end
  end

  test "custom handling of discarded job" do
    perform_enqueued_jobs do
      RetryJob.perform_later "CustomDiscardableError", 2
      assert_equal "Dealt with a job that was discarded in a custom way. Message: CustomDiscardableError", JobBuffer.last_value
    end
  end

  test "custom handling of job that exceeds retry attempts" do
    perform_enqueued_jobs do
      RetryJob.perform_later "CustomCatchError", 6
      assert_equal "Dealt with a job that failed to retry in a custom way after 6 attempts. Message: CustomCatchError", JobBuffer.last_value
    end
  end

  test "long wait job" do
    travel_to Time.now

    perform_enqueued_jobs do
      assert_performed_with at: (Time.now + 3600.seconds).to_i do
        RetryJob.perform_later "LongWaitError", 5
      end
    end
  end

  test "exponentially retrying job" do
    travel_to Time.now

    perform_enqueued_jobs do
      assert_performed_with at: (Time.now + 3.seconds).to_i do
        assert_performed_with at: (Time.now + 18.seconds).to_i do
          assert_performed_with at: (Time.now + 83.seconds).to_i do
            assert_performed_with at: (Time.now + 258.seconds).to_i do
              RetryJob.perform_later "ExponentialWaitTenAttemptsError", 5
            end
          end
        end
      end
    end
  end

  test "custom wait retrying job" do
    travel_to Time.now

    perform_enqueued_jobs do
      assert_performed_with at: (Time.now + 2.seconds).to_i do
        assert_performed_with at: (Time.now + 4.seconds).to_i do
          assert_performed_with at: (Time.now + 6.seconds).to_i do
            assert_performed_with at: (Time.now + 8.seconds).to_i do
              RetryJob.perform_later "CustomWaitTenAttemptsError", 5
            end
          end
        end
      end
    end
  end

  test "successfully retry job throwing one of two retryable exceptions" do
    perform_enqueued_jobs do
      RetryJob.perform_later "SecondRetryableErrorOfTwo", 3

      assert_equal [
        "Raised SecondRetryableErrorOfTwo for the 1st time",
        "Raised SecondRetryableErrorOfTwo for the 2nd time",
        "Successfully completed job" ], JobBuffer.values
    end
  end

  test "discard job throwing one of two discardable exceptions" do
    perform_enqueued_jobs do
      RetryJob.perform_later "SecondDiscardableErrorOfTwo", 2
      assert_equal [ "Raised SecondDiscardableErrorOfTwo for the 1st time" ], JobBuffer.values
    end
  end

  test "successfully retry job throwing DeserializationError" do
    perform_enqueued_jobs do
      RetryJob.perform_later Person.new(404), 5
      assert_equal ["Raised ActiveJob::DeserializationError for the 5 time"], JobBuffer.values
    end
  end
end
