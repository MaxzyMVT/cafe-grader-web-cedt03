require "test_helper"

# A job whose submission was deleted after it was queued (e.g. an old errored job revived by
# "retry all error jobs") must end that one job. It used to raise NoMethodError (RecordNotFound has no
# #end_job) out of the grader loop, killing the whole grader process and stranding the job in "process".
class GraderJobFailureTest < ActiveSupport::TestCase
  setup do
    Job.where(status: :wait).delete_all # only the job under test may be picked up
    @grader = Grader.new(99, 1, 'test-key')
  end

  test "a job for a deleted submission becomes an error and does not crash the grader" do
    missing_id = Submission.maximum(:id).to_i + 1000
    job = Job.create!(job_type: :compile, arg: missing_id, status: :wait, priority: 0, param: { dataset_id: 1 }.to_json)

    ran = nil
    assert_nothing_raised { ran = @grader.check_and_run_job }

    assert ran, "the grader should report that it processed a job"
    job.reload
    assert job.error?, "job should end as error, was #{job.status}"
    assert_match(/Couldn't find Submission/, job.result)
  end

  test "the grader keeps working after such a job" do
    missing_id = Submission.maximum(:id).to_i + 1000
    Job.create!(job_type: :compile, arg: missing_id, status: :wait, priority: 0, param: { dataset_id: 1 }.to_json)
    assert_nothing_raised do
      @grader.check_and_run_job # the bad job
      assert_equal false, @grader.check_and_run_job # queue empty, loop is still alive
    end
  end
end
